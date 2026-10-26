const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const TNC_SITEMAP_URL = "https://careers.tnc.org/us/en/sitemap.xml";
const TNC_JOB_URL_PATTERN = /\/us\/en\/job\/([A-Za-z0-9]+)\//;
const TNC_SOURCE_NAME = "The Nature Conservancy";
const TNC_SOURCE_SITE = "https://careers.tnc.org";
const USER_AGENT = "VetConnectBot/1.0 (+https://veteranapp-afbf4.web.app)";

const CONCURRENCY = 4;
const REQUEST_DELAY_MS = 150; // per worker, between detail page fetches
const MAX_JOBS = 500; // safety cap; TNC posts ~83 today
const FIRESTORE_BATCH_LIMIT = 500;
// Deleting is only safe when we're confident we saw the whole board. If a
// meaningful share of detail pages failed, upsert what we got but leave the
// existing documents alone rather than mistaking a bad run for a hiring freeze.
const MIN_SUCCESS_RATIO = 0.8;

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchText(url) {
  const response = await fetch(url, {headers: {"User-Agent": USER_AGENT}});
  if (!response.ok) {
    throw new Error(`TNC returned HTTP ${response.status} for ${url}`);
  }
  return response.text();
}

// TNC's careers site runs Phenom, which serves page data as a JSON blob
// assigned to `phApp.ddo` inside the server-rendered HTML. Regexing to the
// closing brace would break on nested objects, so walk the string and track
// brace depth, skipping over anything inside a string literal.
function extractJsonObject(text, startIndex) {
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = startIndex; i < text.length; i++) {
    const ch = text[i];

    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === "\"") inString = false;
      continue;
    }

    if (ch === "\"") {
      inString = true;
    } else if (ch === "{") {
      depth++;
    } else if (ch === "}") {
      depth--;
      if (depth === 0) return text.slice(startIndex, i + 1);
    }
  }

  return null;
}

function parseDdo(html) {
  const marker = "phApp.ddo = ";
  const markerIndex = html.indexOf(marker);
  if (markerIndex === -1) return null;

  const braceIndex = html.indexOf("{", markerIndex + marker.length);
  if (braceIndex === -1) return null;

  const json = extractJsonObject(html, braceIndex);
  if (!json) return null;

  try {
    return JSON.parse(json);
  } catch (error) {
    logger.error("Failed to parse phApp.ddo JSON", error);
    return null;
  }
}

// The obvious way to enumerate jobs is to page through /search-results, but
// Phenom serves deep offsets from replicas that disagree about ordering: the
// same `from=40` request returns different jobs run to run, so offset paging
// both repeats and silently skips postings. The sitemap is a single
// deterministic document listing every open requisition, so drive off that.
async function fetchSitemapJobs() {
  const xml = await fetchText(TNC_SITEMAP_URL);
  const jobsById = new Map();

  for (const match of xml.matchAll(/<loc>([^<]+)<\/loc>/g)) {
    const url = match[1].trim();
    const idMatch = url.match(TNC_JOB_URL_PATTERN);
    if (!idMatch) continue;

    jobsById.set(idMatch[1], {jobId: idMatch[1], detailUrl: url});
  }

  return Array.from(jobsById.values()).slice(0, MAX_JOBS);
}

async function fetchJobDetail(detailUrl) {
  const ddo = parseDdo(await fetchText(detailUrl));
  const job = ddo && ddo.jobDetail && ddo.jobDetail.data &&
    ddo.jobDetail.data.job;
  if (!job) throw new Error(`No jobDetail payload at ${detailUrl}`);
  return job;
}

function normalizeJob(raw, jobId, detailUrl) {
  if (!raw.title) return null;

  const latitude = Number(raw.latitude);
  const longitude = Number(raw.longitude);

  return {
    source: "tnc",
    // Carried on every document so the app can attribute each listing without
    // hardcoding a publisher, and so a second job source can be added later
    // without the UI having to special-case where a row came from.
    sourceName: TNC_SOURCE_NAME,
    sourceSite: TNC_SOURCE_SITE,
    jobId,
    title: raw.title,
    detailUrl,
    applyLink: raw.applyUrl || null,
    // Kept for the existing conservation_jobs_page filter dropdown, but now
    // sourced from Phenom's own location string instead of being reverse
    // engineered out of the Workday apply URL. A handful of postings ship with
    // every location field blank, so fall back to the work arrangement
    // ("Hybrid", "Remote") rather than showing nothing at all.
    locationHint: raw.cityStateCountry || raw.location || raw.remote || null,
    city: raw.city || null,
    state: raw.state || null,
    country: raw.country || null,
    postalCode: raw.postalCode || null,
    remote: raw.remote || null,
    lat: Number.isFinite(latitude) ? latitude : null,
    lng: Number.isFinite(longitude) ? longitude : null,
    category: raw.category || null,
    jobFamily: raw.jobFamily || null,
    employmentType: raw.type || null,
    descriptionTeaser: raw.descriptionTeaser || null,
    postedDate: raw.postedDate || null,
  };
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let cursor = 0;

  const runners = Array.from(
      {length: Math.min(limit, items.length)},
      async () => {
        while (cursor < items.length) {
          const index = cursor++;
          results[index] = await worker(items[index]);
          await wait(REQUEST_DELAY_MS);
        }
      },
  );

  await Promise.all(runners);
  return results;
}

async function collectJobs() {
  const listed = await fetchSitemapJobs();

  const settled = await mapWithConcurrency(listed, CONCURRENCY, async (entry) => {
    try {
      const raw = await fetchJobDetail(entry.detailUrl);
      return normalizeJob(raw, entry.jobId, entry.detailUrl);
    } catch (error) {
      logger.warn("Skipping TNC job", {
        jobId: entry.jobId,
        error: error.message,
      });
      return null;
    }
  });

  const jobs = settled.filter(Boolean);
  return {jobs, listedCount: listed.length};
}

async function commitInBatches(db, operations) {
  for (let i = 0; i < operations.length; i += FIRESTORE_BATCH_LIMIT) {
    const batch = db.batch();
    for (const apply of operations.slice(i, i + FIRESTORE_BATCH_LIMIT)) {
      apply(batch);
    }
    await batch.commit();
  }
}

// Upserts everything currently posted and removes anything we stored on a
// previous run that TNC has since taken down -- without this the collection
// only ever grows and the app serves expired postings.
async function syncToFirestore(db, jobs, allowDeletes) {
  const scrapedAt = admin.firestore.FieldValue.serverTimestamp();
  const liveIds = new Set(jobs.map((job) => job.jobId));

  const operations = jobs.map((job) => (batch) => {
    const ref = db.collection("conservation_jobs").doc(job.jobId);
    batch.set(ref, {...job, scrapedAt}, {merge: true});
  });

  let staleRefs = [];
  if (allowDeletes) {
    const existing = await db
        .collection("conservation_jobs")
        .where("source", "==", "tnc")
        .get();

    staleRefs = existing.docs
        .filter((doc) => !liveIds.has(doc.id))
        .map((doc) => doc.ref);

    for (const ref of staleRefs) {
      operations.push((batch) => batch.delete(ref));
    }
  }

  await commitInBatches(db, operations);

  return {upserted: jobs.length, removed: staleRefs.length};
}

async function runSync() {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();

  const {jobs, listedCount} = await collectJobs();
  if (listedCount === 0 || jobs.length === 0) {
    // Bail out rather than emptying the collection if TNC changes their page
    // structure and the parser comes back with nothing.
    throw new Error("TNC returned no parseable jobs; skipping sync");
  }

  const successRatio = jobs.length / listedCount;
  const allowDeletes = successRatio >= MIN_SUCCESS_RATIO;
  if (!allowDeletes) {
    logger.warn("Partial TNC crawl; skipping stale-job cleanup", {
      listedCount,
      parsed: jobs.length,
    });
  }

  const result = await syncToFirestore(db, jobs, allowDeletes);
  logger.info("TNC job sync complete", {...result, listedCount});
  return {...result, listedCount};
}

exports.scrapeTncJobsScheduled = onSchedule(
    {
      schedule: "0 6 * * *",
      timeZone: "America/New_York",
      region: "us-central1",
      timeoutSeconds: 540,
      memory: "256MiB",
    },
    async () => {
      await runSync();
    },
);

// Manual trigger, for backfills and for verifying a parser change without
// waiting for the next scheduled run.
exports.scrapeTncJobs = onCall(
    {timeoutSeconds: 540, memory: "256MiB", region: "us-central1"},
    async () => {
      try {
        return await runSync();
      } catch (error) {
        logger.error("Manual TNC job sync failed", error);
        throw new HttpsError("internal", "Unable to sync TNC jobs right now.");
      }
    },
);

// Discovery pass, kept for recalibrating the parser if TNC changes their page
// structure. Dumps the shape of the payload rather than guessing at it.
exports.scrapeTncJobsDiscover = onCall(
    {timeoutSeconds: 120, memory: "256MiB", region: "us-central1"},
    async () => {
      try {
        const listed = await fetchSitemapJobs();
        if (listed.length === 0) throw new Error("No job URLs in sitemap");

        const raw = await fetchJobDetail(listed[0].detailUrl);

        return {
          sitemapUrl: TNC_SITEMAP_URL,
          listedCount: listed.length,
          sampleUrl: listed[0].detailUrl,
          jobKeys: Object.keys(raw),
          normalized: normalizeJob(raw, listed[0].jobId, listed[0].detailUrl),
        };
      } catch (error) {
        logger.error("TNC discovery failed", error);
        throw new HttpsError(
            "internal",
            "Unable to inspect the TNC careers site right now.",
        );
      }
    },
);
