import 'package:supabase_flutter/supabase_flutter.dart';

class ConflictReviewerDecision {
  final String reviewerId;
  final String displayName;
  final String vote;

  const ConflictReviewerDecision({
    required this.reviewerId,
    required this.displayName,
    required this.vote,
  });
}

class ConflictItem {
  final String articleId;
  final String title;
  final String? doi;
  final List<ConflictReviewerDecision> decisions;
  final String? resolutionMethod;
  final int discussionMessageCount;

  const ConflictItem({
    required this.articleId,
    required this.title,
    required this.doi,
    required this.decisions,
    required this.resolutionMethod,
    required this.discussionMessageCount,
  });

  bool get isResolved => resolutionMethod != null;

  bool get resolvedByDiscussion => resolutionMethod == 'discussion';

  bool get resolvedByArbitration => resolutionMethod == 'arbitration';
}

class ConflictStatistics {
  final List<ConflictItem> conflicts;

  const ConflictStatistics({required this.conflicts});

  int get totalConflicts => conflicts.length;

  int get unresolved =>
      conflicts.where((conflict) => !conflict.isResolved).length;

  int get resolvedByDiscussion =>
      conflicts.where((conflict) => conflict.resolvedByDiscussion).length;

  int get resolvedByArbitration =>
      conflicts.where((conflict) => conflict.resolvedByArbitration).length;

  int get resolved => conflicts.where((conflict) => conflict.isResolved).length;
}

class ConflictService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ConflictStatistics> getStatistics(String projectId) async {
    final results = await Future.wait([
      _client
          .from('articles')
          .select('id, title, doi')
          .eq('project_id', projectId),
      _client
          .from('article_assignments')
          .select('article_id, reviewer_id')
          .eq('project_id', projectId),
      _client
          .from('screening_decisions')
          .select('article_id, reviewer_id, vote')
          .eq('project_id', projectId),
      _client
          .from('project_members')
          .select('user_id, display_name')
          .eq('project_id', projectId),
      _client
          .from('conflict_messages')
          .select('article_id')
          .eq('project_id', projectId),
      _client
          .from('conflict_resolutions')
          .select('article_id, method')
          .eq('project_id', projectId),
    ]);

    final articles = List<Map<String, dynamic>>.from(results[0] as List);
    final assignments = List<Map<String, dynamic>>.from(results[1] as List);
    final decisions = List<Map<String, dynamic>>.from(results[2] as List);
    final members = List<Map<String, dynamic>>.from(results[3] as List);
    final messages = List<Map<String, dynamic>>.from(results[4] as List);
    final resolutions = List<Map<String, dynamic>>.from(results[5] as List);

    final memberNames = <String, String>{
      for (final member in members)
        member['user_id'].toString(): member['display_name'].toString(),
    };

    final articleById = <String, Map<String, dynamic>>{
      for (final article in articles) article['id'].toString(): article,
    };

    final assignedReviewers = <String, Set<String>>{};

    for (final assignment in assignments) {
      final articleId = assignment['article_id'].toString();
      final reviewerId = assignment['reviewer_id'].toString();

      assignedReviewers
          .putIfAbsent(articleId, () => <String>{})
          .add(reviewerId);
    }

    final decisionsByArticle = <String, Map<String, String>>{};

    for (final decision in decisions) {
      final articleId = decision['article_id'].toString();
      final reviewerId = decision['reviewer_id'].toString();

      final reviewers = assignedReviewers[articleId];

      if (reviewers == null || !reviewers.contains(reviewerId)) {
        continue;
      }

      decisionsByArticle.putIfAbsent(
        articleId,
        () => <String, String>{},
      )[reviewerId] = decision['vote']
          .toString();
    }

    final messageCounts = <String, int>{};

    for (final message in messages) {
      final articleId = message['article_id'].toString();
      messageCounts[articleId] = (messageCounts[articleId] ?? 0) + 1;
    }

    final resolutionByArticle = <String, String>{};

    for (final resolution in resolutions) {
      final articleId = resolution['article_id'].toString();
      resolutionByArticle[articleId] = resolution['method'].toString();
    }

    final conflicts = <ConflictItem>[];

    for (final entry in decisionsByArticle.entries) {
      final articleId = entry.key;
      final articleVotes = entry.value;
      final assigned = assignedReviewers[articleId] ?? <String>{};

      // A conflict requires exactly two assigned reviewers and two
      // completed decisions by those assigned reviewers.
      if (assigned.length != 2 || articleVotes.length != 2) {
        continue;
      }

      final votes = articleVotes.values.toSet();

      if (votes.length <= 1) {
        continue;
      }

      final article = articleById[articleId];

      if (article == null) {
        continue;
      }

      final reviewerDecisions =
          articleVotes.entries
              .map(
                (entry) => ConflictReviewerDecision(
                  reviewerId: entry.key,
                  displayName: memberNames[entry.key] ?? 'Unknown reviewer',
                  vote: entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));

      conflicts.add(
        ConflictItem(
          articleId: articleId,
          title: article['title']?.toString() ?? 'Untitled article',
          doi: article['doi']?.toString(),
          decisions: reviewerDecisions,
          resolutionMethod: resolutionByArticle[articleId],
          discussionMessageCount: messageCounts[articleId] ?? 0,
        ),
      );
    }

    conflicts.sort((a, b) {
      if (a.isResolved != b.isResolved) {
        return a.isResolved ? 1 : -1;
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return ConflictStatistics(conflicts: conflicts);
  }
}
