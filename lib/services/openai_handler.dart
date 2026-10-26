import 'package:cloud_functions/cloud_functions.dart';

class OpenaiHandler {
  // AI-powered search query generation: User describes what they want,
  // a Cloud Function calls OpenAI server-side and returns an optimized
  // search query for finding veteran-owned businesses.
  static Future<String> getSearchRecommendation(String userDesire) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'getSearchRecommendation',
      );
      final response = await callable
          .call<Map<String, dynamic>>({'userDesire': userDesire})
          .timeout(const Duration(seconds: 20));

      return (response.data['query'] as String? ?? '').trim();
    } catch (e) {
      print("AI search recommendation failed: $e");
      rethrow;
    }
  }
}
