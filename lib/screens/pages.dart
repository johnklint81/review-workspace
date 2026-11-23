import 'package:material_ui/material_ui.dart';
import '../data/demo_data.dart';
import '../widgets/summary_widgets.dart';
import '../services/project_service.dart';
import '../services/screening_statistics_service.dart';
import 'csv_import_page.dart';
import '../services/conflict_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final projectService = ProjectService();
    final projects = await projectService.getProjects();

    if (projects.isEmpty) {
      throw StateError('No review project is accessible to this account.');
    }

    final project = projects.first;
    final projectId = project['id'].toString();

    final results = await Future.wait([
      projectService.getProjectMembers(projectId),
      ScreeningStatisticsService().getStatistics(projectId),
    ]);

    return _DashboardData(
      projectTitle: project['title'].toString(),
      members: results[0] as List<Map<String, dynamic>>,
      statistics: results[1] as ScreeningStatistics,
    );
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PageFrame(
            title: 'Project overview',
            description: 'Loading PostgreSQL statistics...',
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return PageFrame(
            title: 'Project overview',
            description: 'Unable to load project statistics',
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 12),
                      Text(snapshot.error.toString()),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final data = snapshot.data!;
        final stats = data.statistics;

        final progressPercent = (stats.progress * 100).toStringAsFixed(1);

        final fullyScreenedPercent = stats.totalArticles == 0
            ? 0.0
            : stats.fullyScreenedArticles / stats.totalArticles * 100;

        return PageFrame(
          title: data.projectTitle,
          description:
              'Two independent reviewers per article · PostgreSQL data',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh statistics'),
              ),
            ),
            const SizedBox(height: 12),

            ResponsiveSummaryCards(
              cards: [
                SummaryCard(
                  label: 'Total articles',
                  value: '${stats.totalArticles}',
                  icon: Icons.library_books_outlined,
                ),
                SummaryCard(
                  label: 'Decisions completed',
                  value:
                      '${stats.completedScreenings} / ${stats.requiredScreenings}',
                  icon: Icons.fact_check_outlined,
                ),
                SummaryCard(
                  label: 'Fully screened articles',
                  value: '${stats.fullyScreenedArticles}',
                  icon: Icons.done_all,
                ),
                SummaryCard(
                  label: 'Unresolved conflicts',
                  value: '${stats.openConflicts}',
                  icon: Icons.sync_problem_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decision completion',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$progressPercent% of required screening decisions completed',
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: stats.progress.clamp(0.0, 1.0),
                      minHeight: 12,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${fullyScreenedPercent.toStringAsFixed(1)}% '
                      'of articles have received both decisions. '
                      'Conflict resolution is tracked separately.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review team',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final member in data.members)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member['display_name'].toString()),
                        subtitle: Text(
                          '${stats.reviewerCounts[member['user_id'].toString()] ?? 0} screening decisions',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardData {
  final String projectTitle;
  final List<Map<String, dynamic>> members;
  final ScreeningStatistics statistics;

  const _DashboardData({
    required this.projectTitle,
    required this.members,
    required this.statistics,
  });
}

class ImportPage extends CsvImportPage {
  const ImportPage({super.key});
}

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});
  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = articles
        .where(
          (a) =>
              a.title.toLowerCase().contains(query.toLowerCase()) ||
              a.id.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return PageFrame(
      title: 'Articles',
      description: 'Example articles and two independent screening decisions.',
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search by title or article ID',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              for (final article in filtered)
                ListTile(
                  title: Text(article.title),
                  subtitle: Text(
                    '${article.id} · ${article.firstReviewer}: ${article.firstDecision} · ${article.secondReviewer}: ${article.secondDecision}',
                  ),
                  trailing: Chip(
                    label: Text(
                      article.isConflict
                          ? 'Conflict'
                          : article.isComplete
                          ? 'Complete'
                          : 'Pending',
                    ),
                  ),
                  isThreeLine: true,
                ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No matching articles.'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({super.key});

  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  late Future<ConflictStatistics> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadConflicts();
  }

  Future<ConflictStatistics> _loadConflicts() async {
    final projects = await ProjectService().getProjects();

    if (projects.isEmpty) {
      throw StateError('No accessible review project found.');
    }

    return ConflictService().getStatistics(projects.first['id'].toString());
  }

  void _refresh() {
    setState(() {
      _future = _loadConflicts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConflictStatistics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PageFrame(
            title: 'Conflicts',
            description: 'Loading screening disagreements...',
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return PageFrame(
            title: 'Conflicts',
            description: 'Unable to load conflict data.',
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final statistics = snapshot.data!;

        return PageFrame(
          title: 'Conflicts',
          description: 'Disagreements between the two independent reviewers.',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const SizedBox(height: 12),

            ResponsiveSummaryCards(
              cards: [
                SummaryCard(
                  label: 'Total disagreements',
                  value: '${statistics.totalConflicts}',
                  icon: Icons.sync_problem_outlined,
                ),
                SummaryCard(
                  label: 'Unresolved',
                  value: '${statistics.unresolved}',
                  icon: Icons.forum_outlined,
                ),
                SummaryCard(
                  label: 'Resolved by discussion',
                  value: '${statistics.resolvedByDiscussion}',
                  icon: Icons.forum_outlined,
                ),
                SummaryCard(
                  label: 'Resolved by arbitration',
                  value: '${statistics.resolvedByArbitration}',
                  icon: Icons.gavel_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (statistics.conflicts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No disagreements found. '
                          'Once two assigned reviewers submit different '
                          'decisions for an article, it will appear here.',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final conflict in statistics.conflicts)
                      ListTile(
                        leading: Icon(
                          conflict.isResolved
                              ? Icons.check_circle_outline
                              : Icons.sync_problem_outlined,
                        ),
                        title: Text(conflict.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (conflict.doi != null &&
                                conflict.doi!.isNotEmpty)
                              Text('DOI: ${conflict.doi}'),
                            const SizedBox(height: 4),
                            for (final decision in conflict.decisions)
                              Text(
                                '${decision.displayName}: '
                                '${decision.vote}',
                              ),
                            if (conflict.discussionMessageCount > 0)
                              Text(
                                '${conflict.discussionMessageCount} '
                                'discussion message'
                                '${conflict.discussionMessageCount == 1 ? '' : 's'}',
                              ),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            conflict.isResolved ? 'Resolved' : 'Discuss',
                          ),
                        ),
                        isThreeLine: true,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            const Text(
              'Original reviewer decisions are preserved. '
              'Discussion and arbitration outcomes are tracked separately '
              'from those original decisions.',
            ),
          ],
        );
      },
    );
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<ScreeningStatistics> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadStatistics();
  }

  Future<ScreeningStatistics> _loadStatistics() async {
    final projects = await ProjectService().getProjects();

    if (projects.isEmpty) {
      throw StateError('No accessible review project found.');
    }

    return ScreeningStatisticsService().getStatistics(
      projects.first['id'].toString(),
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadStatistics();
    });
  }

  String _pct(double value) => '${value.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScreeningStatistics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PageFrame(
            title: 'Statistics',
            description:
                'Live screening, agreement, conflict, and reviewer statistics.',
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return PageFrame(
            title: 'Statistics',
            description: 'Unable to load live statistics.',
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final s = snapshot.data!;

        return PageFrame(
          title: 'Statistics',
          description:
              'Live statistics from PostgreSQL for the C. elegans review.',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const SizedBox(height: 12),
            ResponsiveSummaryCards(
              cards: [
                SummaryCard(
                  label: 'Total articles',
                  value: '${s.totalArticles}',
                  icon: Icons.library_books_outlined,
                ),
                SummaryCard(
                  label: 'Decision completion',
                  value: _pct(s.decisionCompletionRate),
                  icon: Icons.percent,
                ),
                SummaryCard(
                  label: 'Fully screened',
                  value: '${s.fullyScreenedArticles}',
                  icon: Icons.done_all,
                ),
                SummaryCard(
                  label: 'Unresolved conflicts',
                  value: '${s.unresolvedConflicts}',
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screening progress',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${s.completedDecisions} of ${s.requiredDecisions} required screening decisions completed.',
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: s.progress.clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        Text('Fully screened: ${s.fullyScreenedArticles}'),
                        Text(
                          'Partially screened: ${s.partiallyScreenedArticles}',
                        ),
                        Text('Not started: ${s.notStartedArticles}'),
                        Text(
                          'Fully assigned (2 reviewers): ${s.fullyAssignedArticles} '
                          '(${_pct(s.assignmentCompletionRate)})',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ResponsiveSummaryCards(
              cards: [
                SummaryCard(
                  label: 'Agreement rate',
                  value: _pct(s.agreementRate),
                  icon: Icons.handshake_outlined,
                ),
                SummaryCard(
                  label: 'Agreements',
                  value: '${s.agreements}',
                  icon: Icons.check_circle_outline,
                ),
                SummaryCard(
                  label: 'Disagreements',
                  value: '${s.disagreements}',
                  icon: Icons.sync_problem_outlined,
                ),
                SummaryCard(
                  label: 'Two-decision articles',
                  value: '${s.screenedWithTwoDecisions}',
                  icon: Icons.fact_check_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conflict resolution',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 28,
                      runSpacing: 12,
                      children: [
                        Text('Unresolved: ${s.unresolvedConflicts}'),
                        Text(
                          'Resolved by discussion: ${s.resolvedByDiscussion}',
                        ),
                        Text(
                          'Resolved by arbitration: ${s.resolvedByArbitration}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A disagreement is counted as unresolved until a conflict resolution record exists. The current schema does not distinguish an intermediate "awaiting arbitration" state.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviewer leaderboard',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completed decisions compared with each reviewer\'s assigned workload.',
                    ),
                    const SizedBox(height: 16),
                    if (s.reviewerStats.isEmpty)
                      const Text('No reviewers found.')
                    else
                      for (final reviewer in s.reviewerStats) ...[
                        Row(
                          children: [
                            Expanded(child: Text(reviewer.displayName)),
                            Text(
                              '${reviewer.completed} / ${reviewer.assigned} '
                              '(${_pct(reviewer.completionRate)})',
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: reviewer.completionRate / 100,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reviewer.remaining} decisions remaining',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                      ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
