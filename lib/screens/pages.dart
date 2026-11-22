import 'package:material_ui/material_ui.dart';
import '../data/demo_data.dart';
import '../widgets/summary_widgets.dart';
import '../services/project_service.dart';
import '../services/screening_statistics_service.dart';


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
      throw StateError(
        'No review project is accessible to this account.',
      );
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

        final progressPercent =
        (stats.progress * 100).toStringAsFixed(1);

        final fullyScreenedPercent = stats.totalArticles == 0
            ? 0.0
            : stats.fullyScreenedArticles /
            stats.totalArticles *
            100;

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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final member in data.members)
                      ListTile(
                        leading: const Icon(
                          Icons.person_outline,
                        ),
                        title: Text(
                          member['display_name'].toString(),
                        ),
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


class ImportPage extends StatelessWidget {
  const ImportPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
    title: 'Import screening results',
    description: 'Planned: CSV exports from Rayyan or ASReview.',
    children: [
      Card(child: Padding(padding: EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.upload_file_outlined, size: 42),
          SizedBox(height: 12),
          Text('Import integration is not enabled yet.'),
          SizedBox(height: 8),
          Text('Upcoming steps: select a file, map its columns, preview records, match article IDs, and confirm the import. Repeat imports must not double-count decisions.'),
        ],
      ))),
    ],
  );
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
    final filtered = articles.where((a) =>
      a.title.toLowerCase().contains(query.toLowerCase()) ||
      a.id.toLowerCase().contains(query.toLowerCase())).toList();
    return PageFrame(
      title: 'Articles',
      description: 'Example articles and two independent screening decisions.',
      children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            labelText: 'Search by title or article ID', border: OutlineInputBorder()),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          for (final article in filtered)
            ListTile(
              title: Text(article.title),
              subtitle: Text('${article.id} · ${article.firstReviewer}: ${article.firstDecision} · ${article.secondReviewer}: ${article.secondDecision}'),
              trailing: Chip(label: Text(article.isConflict ? 'Conflict' : article.isComplete ? 'Complete' : 'Pending')),
              isThreeLine: true,
            ),
          if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No matching articles.')),
        ])),
      ],
    );
  }
}

class ConflictsPage extends StatelessWidget {
  const ConflictsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final demoConflicts = articles.where((a) => a.isConflict).toList();
    return PageFrame(
      title: 'Conflicts',
      description: 'Discussion first; the third author arbitrates if consensus is not reached.',
      children: [
        const ResponsiveSummaryCards(cards: [
          SummaryCard(label: 'Awaiting discussion', value: '48', icon: Icons.forum_outlined),
          SummaryCard(label: 'Awaiting arbitration', value: '12', icon: Icons.gavel_outlined),
        ]),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          for (final a in demoConflicts)
            ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: Text(a.title),
              subtitle: Text('${a.firstReviewer}: ${a.firstDecision} · ${a.secondReviewer}: ${a.secondDecision}'),
              trailing: const Chip(label: Text('Discuss')),
            ),
        ])),
        const SizedBox(height: 12),
        const Text('Discussion notes, consensus decisions, and arbitration actions will become interactive after the backend is connected.'),
      ],
    );
  }
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Statistics',
    description: 'Track assignment-level screening progress separately from article-level completion.',
    children: [
      const ResponsiveSummaryCards(cards: [
        SummaryCard(label: 'Decision completion', value: '75%', icon: Icons.percent),
        SummaryCard(label: 'Fully screened articles', value: '68.3%', icon: Icons.done_all),
        SummaryCard(label: 'Open conflicts', value: '48', icon: Icons.warning_amber_outlined),
        SummaryCard(label: 'Awaiting arbitration', value: '12', icon: Icons.gavel_outlined),
      ]),
      const SizedBox(height: 16),
      const ReviewerLeaderboard(),
      const SizedBox(height: 12),
      const Text('Agreement rates will be calculated from articles with two recorded decisions. Resolved conflicts will retain both original decisions.'),
    ],
  );
}
