import 'package:supabase_flutter/supabase_flutter.dart';

class ScreeningStatistics {
  final int totalArticles;
  final int requiredScreenings;
  final int completedScreenings;
  final int fullyScreenedArticles;
  final int openConflicts;
  final Map<String, int> reviewerCounts;

  const ScreeningStatistics({
    required this.totalArticles,
    required this.requiredScreenings,
    required this.completedScreenings,
    required this.fullyScreenedArticles,
    required this.openConflicts,
    required this.reviewerCounts,
  });

  double get progress => requiredScreenings == 0
      ? 0
      : completedScreenings / requiredScreenings;
}

class ScreeningStatisticsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ScreeningStatistics> getStatistics(String projectId) async {
    final response = await _client.rpc(
      'get_screening_statistics',
      params: {'p_project_id': projectId},
    );

    final data = Map<String, dynamic>.from(response as Map);
    final counts = Map<String, dynamic>.from(data['reviewer_counts'] as Map);

    return ScreeningStatistics(
      totalArticles: (data['total_articles'] as num).toInt(),
      requiredScreenings: (data['required_screenings'] as num).toInt(),
      completedScreenings: (data['completed_screenings'] as num).toInt(),
      fullyScreenedArticles: (data['fully_screened_articles'] as num).toInt(),
      openConflicts: (data['open_conflicts'] as num).toInt(),
      reviewerCounts: counts.map(
            (reviewerId, count) => MapEntry(reviewerId, (count as num).toInt()),
      ),
    );
  }
}