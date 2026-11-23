import 'package:supabase_flutter/supabase_flutter.dart';

class ArticleReviewerDecision {
  final String reviewerId;
  final String reviewerName;
  final String vote;

  const ArticleReviewerDecision({
    required this.reviewerId,
    required this.reviewerName,
    required this.vote,
  });
}

class ReviewArticle {
  final String id;
  final String title;
  final String? doi;
  final String? authors;
  final int? publicationYear;
  final String? source;
  final List<ArticleReviewerDecision> decisions;
  final List<ArticleReviewerAssignment> assignments;
  final bool hasConflict;
  final bool isComplete;

  const ReviewArticle({
    required this.id,
    required this.title,
    required this.doi,
    required this.authors,
    required this.publicationYear,
    required this.source,
    required this.decisions,
    required this.assignments,
    required this.hasConflict,
    required this.isComplete,
  });

  int get completedDecisions => decisions.length;

  int get requiredDecisions => assignments.length;
}

class ArticleReviewerAssignment {
  final String reviewerId;
  final String reviewerName;

  const ArticleReviewerAssignment({
    required this.reviewerId,
    required this.reviewerName,
  });
}

class ArticleService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ReviewArticle>> getArticles(String projectId) async {
    final results = await Future.wait([
      _client
          .from('articles')
          .select('id, title, doi, authors, publication_year, source')
          .eq('project_id', projectId)
          .order('title'),
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
    ]);

    final articleRows = List<Map<String, dynamic>>.from(results[0] as List);
    final assignmentRows = List<Map<String, dynamic>>.from(results[1] as List);
    final decisionRows = List<Map<String, dynamic>>.from(results[2] as List);
    final memberRows = List<Map<String, dynamic>>.from(results[3] as List);

    final memberNames = <String, String>{
      for (final member in memberRows)
        member['user_id'].toString(): member['display_name'].toString(),
    };

    final assignmentsByArticle = <String, List<ArticleReviewerAssignment>>{};

    for (final row in assignmentRows) {
      final articleId = row['article_id'].toString();
      final reviewerId = row['reviewer_id'].toString();

      assignmentsByArticle
          .putIfAbsent(articleId, () => <ArticleReviewerAssignment>[])
          .add(
            ArticleReviewerAssignment(
              reviewerId: reviewerId,
              reviewerName: memberNames[reviewerId] ?? 'Unknown reviewer',
            ),
          );
    }

    final decisionsByArticle = <String, Map<String, String>>{};

    for (final row in decisionRows) {
      final articleId = row['article_id'].toString();
      final reviewerId = row['reviewer_id'].toString();

      final assigned =
          assignmentsByArticle[articleId]?.any(
            (a) => a.reviewerId == reviewerId,
          ) ??
          false;

      if (!assigned) {
        continue;
      }

      decisionsByArticle.putIfAbsent(
        articleId,
        () => <String, String>{},
      )[reviewerId] = row['vote']
          .toString();
    }

    final articles = <ReviewArticle>[];

    for (final row in articleRows) {
      final articleId = row['id'].toString();

      final assignments =
          assignmentsByArticle[articleId] ?? <ArticleReviewerAssignment>[];

      final decisionMap = decisionsByArticle[articleId] ?? <String, String>{};

      final decisions =
          decisionMap.entries
              .map(
                (entry) => ArticleReviewerDecision(
                  reviewerId: entry.key,
                  reviewerName: memberNames[entry.key] ?? 'Unknown reviewer',
                  vote: entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => a.reviewerName.compareTo(b.reviewerName));

      final hasConflict =
          decisions.length >= 2 &&
          decisions.map((d) => d.vote).toSet().length > 1;

      final isComplete =
          assignments.isNotEmpty && decisions.length == assignments.length;

      articles.add(
        ReviewArticle(
          id: articleId,
          title: row['title']?.toString() ?? 'Untitled article',
          doi: row['doi']?.toString(),
          authors: row['authors']?.toString(),
          publicationYear: (row['publication_year'] as num?)?.toInt(),
          source: row['source']?.toString(),
          decisions: decisions,
          assignments: assignments,
          hasConflict: hasConflict,
          isComplete: isComplete,
        ),
      );
    }

    return articles;
  }
}
