class ReviewArticle {
  final String id;
  final String title;
  final String firstReviewer;
  final String secondReviewer;
  final String firstDecision;
  final String secondDecision;

  const ReviewArticle(this.id, this.title, this.firstReviewer,
      this.secondReviewer, this.firstDecision, this.secondDecision);

  bool get isComplete => firstDecision != 'Pending' && secondDecision != 'Pending';
  bool get isConflict => isComplete && firstDecision != secondDecision;
}

class ReviewerProgress {
  final String name;
  final int completed;
  final int assigned;
  const ReviewerProgress(this.name, this.completed, this.assigned);
}

// All numbers and articles in this file are illustrative, not actual research data.
const totalArticles = 1200;
const requiredDecisions = 2400;
const completedDecisions = 1800;
const fullyScreenedArticles = 820;
const openConflicts = 48;
const awaitingArbitration = 12;

const reviewers = [
  ReviewerProgress('Author A', 680, 840),
  ReviewerProgress('Author B', 610, 800),
  ReviewerProgress('Author C', 510, 760),
];

const articles = [
  ReviewArticle('A-001', 'Digital interventions and patient outcomes', 'Author A', 'Author B', 'Include', 'Include'),
  ReviewArticle('A-002', 'A qualitative study of implementation barriers', 'Author A', 'Author C', 'Include', 'Exclude'),
  ReviewArticle('A-003', 'Protocol for a longitudinal cohort study', 'Author B', 'Author C', 'Exclude', 'Exclude'),
  ReviewArticle('A-004', 'Effects of structured support programmes', 'Author B', 'Author A', 'Include', 'Pending'),
  ReviewArticle('A-005', 'An observational multi-centre analysis', 'Author C', 'Author B', 'Exclude', 'Include'),
  ReviewArticle('A-006', 'Review of technology-assisted screening', 'Author A', 'Author C', 'Pending', 'Pending'),
];
