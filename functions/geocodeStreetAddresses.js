const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const geocodingApiKey = defineSecret("GOOGLE_GEOCODING_API_KEY");

const USER_AGENT = "VetConnectBot/1.0 (+https://veteranapp-afbf4.web.app)";
const GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json";

// Only ~13% of listings publish a street address; the rest carry nothing
// beyond "City, ST ZIP" and are already as precise as they can be at the ZIP
// centroid. This upgrades just that minority to a real per-business pin.
const DEFAULT_LIMIT = 2000;
// Google's free tier is 10,000 geocodes per month. Stay well under it so a
// re-run can never quietly produce a bill.
const MAX_LIMIT = 2000;
const REQUEST_DELAY_MS = 120;
const FIRESTORE_BATCH_LIMIT = 500;
// Consecutive fetch failures before giving up on a run. The site returns 403
// once it decides traffic is automated, and every later request fails too.
const FAILURE_CIRCUIT_BREAKER = 10;

const PENDING_SOURCE = "census-zcta-centroid";
// Listings checked once and found to have no usable street address. Marking
// them keeps later runs from re-fetching the same pages forever.
const EXHAUSTED_SOURCE = "census-zcta-centroid-final";

const STREET_ADDRESS_PATTERN = /"streetAddress"\s*:\s*"([^"]*)"/;
// A usable address starts with a house number or carries a street suffix.
// Plenty of listings put the business name in this field instead.
const LOOKS_LIKE_STREET = new RegExp(
    "^\\d|P\\.?O\\.? ?Box|" +
    "\\b(st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|" +
    "way|hwy|highway|pkwy|parkway|ct|court|pl|place|suite|ste|unit)\\b\\.?",
    "i",
);

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function decodeEntities(text) {
  return String(text || "")
      .replace(/&amp;/g, "&")
      .replace(/&#0?39;/g, "'")
      .replace(/&quot;/g, "\"")
      .replace(/&nbsp;/g, " ")
      .replace(/\s+/g, " ")
      .trim();
}

async function fetchStreetAddress(sourceUrl) {
  const response = await fetch(sourceUrl, {
    headers: {"User-Agent": USER_AGENT},
  });
  // Throw rather than return null: the caller treats null as "this listing
  // publishes no address" and marks the document so it is never checked
  // again. A 403 or 503 means we could not look, not that there is nothing
  // to find, and must never be recorded as a final answer.
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${sourceUrl}`);
  }

  const match = (await response.text()).match(STREET_ADDRESS_PATTERN);
  if (!match) return null;

  const street = decodeEntities(match[1]);
  if (!street || !LOOKS_LIKE_STREET.test(street)) return null;
  return street;
}

async function geocode(address, apiKey) {
  const url = `${GEOCODE_URL}?address=${encodeURIComponent(address)}` +
    `&key=${apiKey}`;

  const response = await fetch(url);
  if (!response.ok) throw new Error(`Geocoder HTTP ${response.status}`);

  const body = await response.json();
  if (body.status === "ZERO_RESULTS") return null;
  if (body.status !== "OK") {
    // OVER_QUERY_LIMIT / REQUEST_DENIED are fatal for the whole run, not just
    // this address, so surface them rather than silently skipping.
    throw new Error(`Geocoder status ${body.status}: ${body.error_message}`);
  }

  const result = body.results[0];
  const location = result && result.geometry && result.geometry.location;
  if (!location) return null;

  return {
    lat: location.lat,
    lng: location.lng,
    formattedAddress: result.formatted_address || null,
    locationType: (result.geometry.location_type || "").toLowerCase() || null,
  };
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

// Walks businesses still sitting on a ZIP centroid, looks for a street
// address on their listing page, and upgrades the ones that have a usable
// address to real coordinates.
//
// Every document is marked either way, so each pass permanently shrinks the
// backlog and a repeat run never re-checks the same listing. Once the backlog
// is cleared the query returns almost nothing and the run is a cheap no-op
// that just picks up whatever the monthly scrape added.
async function runGeocodePass({dryRun = false, limit = DEFAULT_LIMIT} = {}) {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();

  const cappedLimit = Math.min(Number(limit) || DEFAULT_LIMIT, MAX_LIMIT);
  const apiKey = geocodingApiKey.value();
  if (!apiKey && !dryRun) {
    throw new HttpsError(
        "failed-precondition",
        "GOOGLE_GEOCODING_API_KEY secret is not set.",
    );
  }

  const snapshot = await db
      .collection("known_businesses")
      .where("business.geocodeSource", "==", PENDING_SOURCE)
      .limit(cappedLimit)
      .get();

  const operations = [];
  let geocoded = 0;
  let noAddress = 0;
  let notFound = 0;
  let fetchFailed = 0;
  let consecutiveFailures = 0;
  let aborted = false;
  const samples = [];

  for (const doc of snapshot.docs) {
    const business = doc.data().business;
    if (!business || !business.sourceUrl) continue;

    let street;
    try {
      street = await fetchStreetAddress(business.sourceUrl);
      consecutiveFailures = 0;
    } catch (error) {
      fetchFailed++;
      consecutiveFailures++;
      // If the site is blocking or down, every remaining fetch will fail too.
      // Stop rather than sending another two thousand doomed requests.
      if (consecutiveFailures >= FAILURE_CIRCUIT_BREAKER) {
        logger.warn("Aborting run: source unreachable", {
          consecutiveFailures,
          lastError: error.message,
        });
        aborted = true;
        break;
      }
      continue;
    }

    if (!street) {
      noAddress++;
      if (!dryRun) {
        operations.push((batch) => {
          batch.set(
              doc.ref,
              {business: {geocodeSource: EXHAUSTED_SOURCE}},
              {merge: true},
          );
        });
      }
      continue;
    }

    const query = [
      street,
      business.city,
      business.state,
      business.postalCode,
    ].filter(Boolean).join(", ");

    if (dryRun) {
      if (samples.length < 10) samples.push({id: doc.id, query});
      continue;
    }

    const point = await geocode(query, apiKey);
    await wait(REQUEST_DELAY_MS);

    if (!point) {
      notFound++;
      continue;
    }

    geocoded++;
    operations.push((batch) => {
      batch.set(
          doc.ref,
          {
            business: {
              streetAddress: street,
              lat: point.lat,
              lng: point.lng,
              geocodeSource: "google-street",
              geocodeFormattedAddress: point.formattedAddress,
              geocodeAccuracy: point.locationType,
              geocodeUpdatedAt: new Date().toISOString(),
            },
          },
          {merge: true},
      );
    });

    if (samples.length < 10) {
      samples.push({id: doc.id, query, result: point.formattedAddress});
    }
  }

  if (!dryRun) await commitInBatches(db, operations);

  const summary = {
    dryRun,
    scanned: snapshot.size,
    geocoded,
    noStreetAddress: noAddress,
    notFound,
    fetchFailed,
    aborted,
    remainingHint: aborted ?
      "source unreachable" :
      snapshot.size < cappedLimit ? "backlog cleared" : "more",
    samples,
  };

  logger.info("Street geocoding pass complete", summary);
  return summary;
}

// Puts listings marked "no address published" back in the queue.
//
// Needed when a run recorded that verdict wrongly -- the source returning 403
// for every request looks identical to every listing lacking an address
// unless failures are separated from genuine misses.
async function resetExhausted(db, limit) {
  const snapshot = await db
      .collection("known_businesses")
      .where("business.geocodeSource", "==", EXHAUSTED_SOURCE)
      .limit(limit)
      .get();

  await commitInBatches(
      db,
      snapshot.docs.map((doc) => (batch) => {
        batch.set(
            doc.ref,
            {business: {geocodeSource: PENDING_SOURCE}},
            {merge: true},
        );
      }),
  );

  return snapshot.size;
}

// Daily rather than weekly: the backlog needs ~14 passes either way, so the
// interval decides whether that takes a fortnight or half a year.
exports.geocodeStreetAddressesScheduled = onSchedule(
    {
      schedule: "0 5 * * *",
      timeZone: "America/New_York",
      secrets: [geocodingApiKey],
      region: "us-central1",
      timeoutSeconds: 1800,
      memory: "512MiB",
    },
    async () => {
      await runGeocodePass();
    },
);

// Manual trigger, for dry runs and for working through the backlog faster
// than one pass a day.
exports.geocodeStreetAddresses = onCall(
    {
      secrets: [geocodingApiKey],
      timeoutSeconds: 1800,
      memory: "512MiB",
      region: "us-central1",
    },
    async (request) => {
      const data = request.data || {};
      try {
        if (data.reset) {
          if (!admin.apps.length) admin.initializeApp();
          const requeued = await resetExhausted(
              admin.firestore(),
              Math.min(Number(data.limit) || MAX_LIMIT, MAX_LIMIT),
          );
          return {reset: true, requeued};
        }

        return await runGeocodePass({
          dryRun: Boolean(data.dryRun),
          limit: data.limit,
        });
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("Street geocoding failed", error);
        throw new HttpsError("internal", "Unable to geocode right now.");
      }
    },
);
