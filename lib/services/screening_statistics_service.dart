import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewerStatistic {
  final String userId;
  final String displayName;
  final int assigned;
  final int completed;
  final int remaining;
  final double completionRate;

  const ReviewerStatistic({
    required this.userId,
    required this.displayName,
    required this.assigned,
    required this.completed,
    required this.remaining,
    required this.completionRate,
  });
}

class ScreeningStatistics {
  final int totalArticles;
  final int fullyAssignedArticles;
  final double assignmentCompletionRate;
  final int requiredDecisions;
  final int completedDecisions;
  final double decisionCompletionRate;
  final int fullyScreenedArticles;
  final int partiallyScreenedArticles;
  final int notStartedArticles;
  final int screenedWithTwoDecisions;
  final int agreements;
  final int disagreements;
  final double agreementRate;
  final int unresolvedConflicts;
  final int resolvedByDiscussion;
  final int resolvedByArbitration;
  final List<ReviewerStatistic> reviewerStats;

  const ScreeningStatistics({
    required this.totalArticles,
    required this.fullyAssignedArticles,
    required this.assignmentCompletionRate,
    required this.requiredDecisions,
    required this.completedDecisions,
    required this.decisionCompletionRate,
    required this.fullyScreenedArticles,
    required this.partiallyScreenedArticles,
    required this.notStartedArticles,
    required this.screenedWithTwoDecisions,
    required this.agreements,
    required this.disagreements,
    required this.agreementRate,
    required this.unresolvedConflicts,
    required this.resolvedByDiscussion,
    required this.resolvedByArbitration,
    required this.reviewerStats,
  });

  double get progress => decisionCompletionRate / 100.0;
  // Backward-compatible names used by the Dashboard.
  int get completedScreenings => completedDecisions;

  int get requiredScreenings => requiredDecisions;

  int get openConflicts => unresolvedConflicts;

  Map<String, int> get reviewerCounts => {
    for (final reviewer in reviewerStats) reviewer.userId: reviewer.completed,
  };
  factory ScreeningStatistics.fromMap(Map<String, dynamic> data) {
    final reviewers = (data['reviewer_stats'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(
          (item) => ReviewerStatistic(
            userId: item['user_id'].toString(),
            displayName: item['display_name'].toString(),
            assigned: (item['assigned'] as num?)?.toInt() ?? 0,
            completed: (item['completed'] as num?)?.toInt() ?? 0,
            remaining: (item['remaining'] as num?)?.toInt() ?? 0,
            completionRate: (item['completion_rate'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();

    return ScreeningStatistics(
      totalArticles: (data['total_articles'] as num?)?.toInt() ?? 0,
      fullyAssignedArticles:
          (data['fully_assigned_articles'] as num?)?.toInt() ?? 0,
      assignmentCompletionRate:
          (data['assignment_completion_rate'] as num?)?.toDouble() ?? 0,
      requiredDecisions: (data['required_decisions'] as num?)?.toInt() ?? 0,
      completedDecisions: (data['completed_decisions'] as num?)?.toInt() ?? 0,
      decisionCompletionRate:
          (data['decision_completion_rate'] as num?)?.toDouble() ?? 0,
      fullyScreenedArticles:
          (data['fully_screened_articles'] as num?)?.toInt() ?? 0,
      partiallyScreenedArticles:
          (data['partially_screened_articles'] as num?)?.toInt() ?? 0,
      notStartedArticles: (data['not_started_articles'] as num?)?.toInt() ?? 0,
      screenedWithTwoDecisions:
          (data['screened_with_two_decisions'] as num?)?.toInt() ?? 0,
      agreements: (data['agreements'] as num?)?.toInt() ?? 0,
      disagreements: (data['disagreements'] as num?)?.toInt() ?? 0,
      agreementRate: (data['agreement_rate'] as num?)?.toDouble() ?? 0,
      unresolvedConflicts: (data['unresolved_conflicts'] as num?)?.toInt() ?? 0,
      resolvedByDiscussion:
          (data['resolved_by_discussion'] as num?)?.toInt() ?? 0,
      resolvedByArbitration:
          (data['resolved_by_arbitration'] as num?)?.toInt() ?? 0,
      reviewerStats: reviewers,
    );
  }
}

class ScreeningStatisticsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ScreeningStatistics> getStatistics(String projectId) async {
    final response = await _client.rpc(
      'get_review_statistics',
      params: {'p_project_id': projectId},
    );

    return ScreeningStatistics.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
