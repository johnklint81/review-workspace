import 'package:material_ui/material_ui.dart';
import '../data/demo_data.dart';
import '../widgets/summary_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Project overview',
    description: 'Two independent reviewers per article · fictional demonstration data',
    children: [
      const ResponsiveSummaryCards(cards: [
        SummaryCard(label: 'Total articles', value: '1,200', icon: Icons.library_books_outlined),
        SummaryCard(label: 'Decisions completed', value: '1,800 / 2,400', icon: Icons.fact_check_outlined),
        SummaryCard(label: 'Fully screened articles', value: '820', icon: Icons.done_all),
        SummaryCard(label: 'Unresolved conflicts', value: '48', icon: Icons.sync_problem_outlined),
      ]),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Decision completion', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('75% of required individual screening decisions completed'),
          const SizedBox(height: 12),
          const LinearProgressIndicator(value: completedDecisions / requiredDecisions, minHeight: 12),
          const SizedBox(height: 12),
          const Text('68.3% of articles have received both decisions. Conflict resolution is tracked separately.'),
        ],
      ))),
      const SizedBox(height: 16),
      const ReviewerLeaderboard(),
    ],
  );
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
