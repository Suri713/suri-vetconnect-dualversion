const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const OpenAI = require("openai");

const tncJobs = require("./scrapeTncJobs");
exports.scrapeTncJobsScheduled = tncJobs.scrapeTncJobsScheduled;
exports.scrapeTncJobs = tncJobs.scrapeTncJobs;
exports.scrapeTncJobsDiscover = tncJobs.scrapeTncJobsDiscover;

const postalBackfill = require("./backfillPostalCodes");
exports.backfillPostalCodes = postalBackfill.backfillPostalCodes;

const streetGeocoder = require("./geocodeStreetAddresses");
exports.geocodeStreetAddressesScheduled =
  streetGeocoder.geocodeStreetAddressesScheduled;
exports.geocodeStreetAddresses = streetGeocoder.geocodeStreetAddresses;

const vobBusinesses = require("./scrapeVobBusinesses");
exports.scrapeVobBusinessesScheduled =
  vobBusinesses.scrapeVobBusinessesScheduled;
exports.scrapeVobBusinesses = vobBusinesses.scrapeVobBusinesses;
exports.scrapeVobBusinessesDiscover =
  vobBusinesses.scrapeVobBusinessesDiscover;

const openaiApiKey = defineSecret("OPENAI_API_KEY");

const SYSTEM_PROMPT = `You are a search query generator for a veteran-owned business directory.

Your task: Convert user descriptions into effective search queries for finding businesses.

Rules:
- Focus on business types, services, or categories that veterans might own
- Keep queries concise (1-5 words when possible)
- Return ONLY the search query as plain text
- Remove any extra explanation or formatting
- Examples:
  User: "I need car repairs" → "auto repair"
  User: "Looking for good coffee" → "coffee shop"
  User: "Veteran owned restaurants" → "restaurant"
  User: "I want to buy local art" → "art gallery"`;

exports.getSearchRecommendation = onCall(
    {secrets: [openaiApiKey], region: "us-central1"},
    async (request) => {
      const userDesire = request.data && request.data.userDesire;

      if (typeof userDesire !== "string" || userDesire.trim().length === 0) {
        throw new HttpsError(
            "invalid-argument",
            "userDesire must be a non-empty string.",
        );
      }
      if (userDesire.length > 500) {
        throw new HttpsError(
            "invalid-argument",
            "userDesire must be 500 characters or fewer.",
        );
      }

      const client = new OpenAI({apiKey: openaiApiKey.value()});

      try {
        const completion = await client.chat.completions.create({
          model: "gpt-3.5-turbo",
          messages: [
            {role: "system", content: SYSTEM_PROMPT},
            {role: "user", content: `User request: ${userDesire.trim()}`},
          ],
          temperature: 0.3,
          max_tokens: 50,
        });

        const text = completion.choices?.[0]?.message?.content ?? "";
        return {query: text.trim()};
      } catch (error) {
        console.error("OpenAI request failed:", error);
        throw new HttpsError(
            "internal",
            "Unable to generate a search recommendation right now.",
        );
      }
    },
);
