const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Documents imported before the scraper stored structured fields keep their
// location only as free text ("Woodbine, MD 21797"), which Firestore cannot
// query by ZIP. This one-off backfill parses that string into
// business.postalCode / city / state so the map can look businesses up by ZIP.
const LOCATION_PATTERN = /^(.*),\s*([A-Za-z]{2})\s+(\d{5})(?:-\d{4})?$/;
const FIRESTORE_BATCH_LIMIT = 500;

function parseLocation(raw) {
  const match = String(raw || "").trim().match(LOCATION_PATTERN);
  if (!match) return null;

  return {
    city: match[1].trim() || null,
    state: match[2].toUpperCase(),
    postalCode: match[3],
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

exports.backfillPostalCodes = onCall(
    {timeoutSeconds: 540, memory: "512MiB", region: "us-central1"},
    async (request) => {
      if (!admin.apps.length) admin.initializeApp();
      const db = admin.firestore();

      // Pass {dryRun: true} to see what would change without writing.
      const dryRun = Boolean(request.data && request.data.dryRun);

      const snapshot = await db.collection("known_businesses").get();

      const operations = [];
      let alreadySet = 0;
      let unparseable = 0;
      const samples = [];

      for (const doc of snapshot.docs) {
        const business = doc.data().business;
        if (!business || typeof business !== "object") continue;

        if (business.postalCode) {
          alreadySet++;
          continue;
        }

        const parsed = parseLocation(business.locationRaw);
        if (!parsed) {
          unparseable++;
          if (samples.length < 5) {
            samples.push({id: doc.id, locationRaw: business.locationRaw});
          }
          continue;
        }

        operations.push((batch) => {
          batch.set(doc.ref, {business: parsed}, {merge: true});
        });
      }

      if (!dryRun) await commitInBatches(db, operations);

      const summary = {
        dryRun,
        scanned: snapshot.size,
        updated: operations.length,
        alreadySet,
        unparseable,
        unparseableSamples: samples,
      };

      logger.info("Postal code backfill complete", summary);
      return summary;
    },
);

exports._parseLocation = parseLocation;
