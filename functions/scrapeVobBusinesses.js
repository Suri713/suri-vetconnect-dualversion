const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const zipCentroids = require("./data/zip_centroids.json");

const VOB_BASE_URL = "https://www.veteranownedbusiness.com";
const VOB_SOURCE_NAME = "VeteranOwnedBusiness.com";
const USER_AGENT = "VetConnectBot/1.0 (+https://veteranapp-afbf4.web.app)";

// One page per state/territory -- each returns every listing for that state in
// a single response, so there is no pagination to walk.
const STATES = [
  "al", "ak", "az", "ar", "ca", "co", "ct", "de", "fl", "ga", "hi", "id",
  "il", "in", "ia", "ks", "ky", "la", "me", "md", "ma", "mi", "mn", "ms",
  "mo", "mt", "ne", "nv", "nh", "nj", "nm", "ny", "nc", "nd", "oh", "ok",
  "or", "pa", "ri", "sc", "sd", "tn", "tx", "ut", "vt", "va", "wa", "wv",
  "wi", "wy", "dc", "pr", "gu",
  // No /vi, /as or /mp -- those territory pages 404 on the site, so including
  // them just burns three requests and three failures every run.
];

const REQUEST_DELAY_MS = 1000; // one page per second; these are ~1.5MB each
const FIRESTORE_BATCH_LIMIT = 500;
const MAX_SEARCH_TOKENS = 40;
// Only prune listings when we're confident we saw the whole directory. A run
// that lost a chunk of states should add what it found, not delete the rest.
const MIN_STATE_SUCCESS_RATIO = 0.9;

// Each listing row looks like:
//   <tr class="top_level_listing"><td><a href="/business/100/slug">Name</a>
//   | <span class="info">Anthony, TX 79821<br />Description...</span></td></tr>
const LISTING_PATTERN = new RegExp(
    "<a href=\"/business/(\\d+)/([^\"]*)\">([^<]*)</a>\\s*\\|\\s*" +
    "<span class=\"info\">([^<]*)<br\\s*/?>([\\s\\S]*?)</span>",
    "gi",
);
const LOCATION_PATTERN = /^(.*),\s*([A-Z]{2})\s+(\d{5})(?:-\d{4})?$/;

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function decodeEntities(text) {
  return String(text || "")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&#0?39;/g, "'")
      .replace(/&apos;/g, "'")
      .replace(/&nbsp;/g, " ")
      .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
      .replace(/\s+/g, " ")
      .trim();
}

// Listing descriptions carry a "Rel: 0" relevance artifact from the site's
// own search ranking. It is not part of the business description and it was
// polluting the search index on the previous import, so strip it.
function cleanDescription(text) {
  return decodeEntities(text).replace(/^Rel:\s*-?\d+\s*/i, "").trim();
}

function parseLocation(raw) {
  const match = decodeEntities(raw).match(LOCATION_PATTERN);
  if (!match) return {city: null, state: null, zip: null};

  return {
    city: match[1].trim() || null,
    state: match[2],
    zip: match[3],
  };
}

// Geocoding by ZIP centroid rather than the paid Geocoding API. The previous
// import only ever asked Google to resolve "City, ST ZIP" anyway, so the
// Census centroid for that ZIP is the same answer for free.
function geocodeByZip(zip) {
  const point = zip && zipCentroids[zip];
  if (!point) return {lat: null, lng: null};
  return {lat: point[0], lng: point[1]};
}

function buildSearchIndex(name, description) {
  const tokens = Array.from(
      new Set(
          `${name} ${description}`
              .toLowerCase()
              .replace(/[^a-z0-9\s]/g, " ")
              .split(/\s+/)
              .filter((word) => word.length >= 2),
      ),
  ).sort().slice(0, MAX_SEARCH_TOKENS);

  const prefixes = new Set();
  for (const token of tokens) {
    // Start at 2 characters and include the whole token, so the app's
    // arrayContainsAny lookup matches both partial and exact words.
    for (let length = 2; length <= token.length; length++) {
      prefixes.add(token.slice(0, length));
    }
  }

  return {searchTokens: tokens, searchPrefixes: Array.from(prefixes).sort()};
}

function parseStatePage(html) {
  const listings = [];

  for (const match of html.matchAll(LISTING_PATTERN)) {
    const [, id, slug, rawName, rawLocation, rawDescription] = match;

    const name = decodeEntities(rawName);
    if (!name) continue;

    const description = cleanDescription(rawDescription);
    const {city, state, zip} = parseLocation(rawLocation);
    const {lat, lng} = geocodeByZip(zip);

    listings.push({
      id,
      name,
      description,
      locationRaw: decodeEntities(rawLocation) || null,
      city,
      state,
      zip,
      lat,
      lng,
      sourceUrl: `${VOB_BASE_URL}/business/${id}/${slug}`,
    });
  }

  return listings;
}

// Matches the document shape the app already reads: firebase_helper.dart
// pulls `business` out of the document and queries `searchPrefixes`.
function toDocument(listing, geocodedAt) {
  const {searchTokens, searchPrefixes} =
    buildSearchIndex(listing.name, listing.description);

  return {
    business: {
      id: listing.id,
      name: listing.name,
      description: listing.description,
      locationRaw: listing.locationRaw,
      city: listing.city,
      state: listing.state,
      postalCode: listing.zip,
      lat: listing.lat,
      lng: listing.lng,
      geocodeSource: listing.lat === null ? null : "census-zcta-centroid",
      geocodeUpdatedAt: geocodedAt,
      photoUrls: [],
      sourceUrl: listing.sourceUrl,
      sourceName: VOB_SOURCE_NAME,
    },
    source: "vob",
    businessName: listing.name,
    businessNameLower: listing.name.toLowerCase(),
    businessDescriptionLower: listing.description.toLowerCase(),
    searchTokens,
    searchPrefixes,
  };
}

async function fetchStateListings(state) {
  const url = `${VOB_BASE_URL}/${state}`;
  const response = await fetch(url, {headers: {"User-Agent": USER_AGENT}});
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  return parseStatePage(await response.text());
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

// Walks the directory one state at a time, writing each state's listings
// before moving on so peak memory stays at roughly one page rather than all
// ~29,000 documents at once.
async function syncStates(db, states) {
  const geocodedAt = new Date().toISOString();
  const seenIds = new Set();
  let statesParsed = 0;
  let geocoded = 0;

  for (const state of states) {
    if (statesParsed > 0) await wait(REQUEST_DELAY_MS);

    let listings;
    try {
      listings = await fetchStateListings(state);
    } catch (error) {
      logger.warn("Skipping state", {state, error: error.message});
      continue;
    }

    const operations = [];
    for (const listing of listings) {
      if (seenIds.has(listing.id)) continue;
      seenIds.add(listing.id);
      if (listing.lat !== null) geocoded++;

      const doc = toDocument(listing, geocodedAt);
      operations.push((batch) => {
        batch.set(
            db.collection("known_businesses").doc(listing.id),
            doc,
            {merge: true},
        );
      });
    }

    await commitInBatches(db, operations);
    statesParsed++;
    logger.info("Synced state", {state, listings: operations.length});
  }

  return {
    upserted: seenIds.size,
    geocoded,
    statesParsed,
    statesTotal: states.length,
    seenIds,
  };
}

// Removes listings this scraper previously wrote that are no longer in the
// directory. Scoped to source == "vob" so businesses created by app users are
// never touched.
async function removeDelisted(db, seenIds) {
  const existing = await db
      .collection("known_businesses")
      .where("source", "==", "vob")
      .get();

  const staleRefs = existing.docs
      .filter((doc) => !seenIds.has(doc.id))
      .map((doc) => doc.ref);

  await commitInBatches(
      db,
      staleRefs.map((ref) => (batch) => batch.delete(ref)),
  );

  return staleRefs.length;
}

// A full 56-state crawl does not reliably fit in one invocation -- the large
// states each take several seconds to fetch, parse and write -- so callers can
// pass a subset and work through the directory in chunks. Delisted-cleanup
// only makes sense once the whole directory has been seen, so a partial run
// never deletes.
async function runSync({states} = {}) {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();

  const isPartial = Array.isArray(states) && states.length > 0;
  const targetStates = isPartial ? states : STATES;

  const invalid = targetStates.filter((state) => !STATES.includes(state));
  if (invalid.length > 0) {
    throw new HttpsError(
        "invalid-argument",
        `Unknown state(s): ${invalid.join(", ")}`,
    );
  }

  const result = await syncStates(db, targetStates);
  if (result.upserted === 0) {
    throw new Error("No listings parsed; skipping sync");
  }

  const successRatio = result.statesParsed / result.statesTotal;
  let removed = 0;

  if (isPartial) {
    logger.info("Partial state list; skipping delisted cleanup", {
      states: targetStates,
    });
  } else if (successRatio >= MIN_STATE_SUCCESS_RATIO) {
    removed = await removeDelisted(db, result.seenIds);
  } else {
    logger.warn("Partial directory crawl; skipping delisted cleanup", {
      statesParsed: result.statesParsed,
      statesTotal: result.statesTotal,
    });
  }

  const summary = {
    upserted: result.upserted,
    geocoded: result.geocoded,
    removed,
    statesParsed: result.statesParsed,
    statesTotal: result.statesTotal,
  };
  logger.info("VOB business sync complete", summary);
  return summary;
}

exports.scrapeVobBusinessesScheduled = onSchedule(
    {
      schedule: "0 4 1 * *", // 1st of the month; the directory adds ~175/mo
      timeZone: "America/New_York",
      region: "us-central1",
      // A full sweep of ~28,500 listings across 53 states takes ~13 minutes.
      // 540s is not enough -- the first manual run timed out at 32 states.
      timeoutSeconds: 1800,
      memory: "1GiB",
    },
    async () => {
      await runSync();
    },
);

exports.scrapeVobBusinesses = onCall(
    {timeoutSeconds: 540, memory: "1GiB", region: "us-central1"},
    async (request) => {
      try {
        // {states: ["tx", "ok"]} runs just those; omit for the full directory.
        return await runSync({states: request.data && request.data.states});
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("Manual VOB business sync failed", error);
        throw new HttpsError(
            "internal",
            "Unable to sync veteran-owned businesses right now.",
        );
      }
    },
);

// Parses a single state without writing anything, for checking the selectors
// still match after a site change.
exports.scrapeVobBusinessesDiscover = onCall(
    {timeoutSeconds: 120, memory: "512MiB", region: "us-central1"},
    async (request) => {
      const state = (request.data && request.data.state) || "tx";
      if (!STATES.includes(state)) {
        throw new HttpsError("invalid-argument", `Unknown state "${state}".`);
      }

      try {
        const listings = await fetchStateListings(state);
        return {
          state,
          count: listings.length,
          geocoded: listings.filter((l) => l.lat !== null).length,
          sample: listings.slice(0, 3),
          sampleDocument: listings[0] ?
            toDocument(listings[0], new Date().toISOString()) :
            null,
        };
      } catch (error) {
        logger.error("VOB discovery failed", error);
        throw new HttpsError(
            "internal",
            "Unable to inspect the directory right now.",
        );
      }
    },
);
