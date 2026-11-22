import 'package:material_ui/material_ui.dart';
import '../data/demo_data.dart';

class PageFrame extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;
  const PageFrame({super.key, required this.title, required this.description, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 24),
      ...children,
    ],
  );
}

class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const SummaryCard({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ]),
    ),
  );
}

class ResponsiveSummaryCards extends StatelessWidget {
  final List<SummaryCard> cards;
  const ResponsiveSummaryCards({super.key, required this.cards});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 520 ? 2 : 1);
      return GridView.count(
        crossAxisCount: count, mainAxisSpacing: 12, crossAxisSpacing: 12,
        childAspectRatio: count == 1 ? 3.1 : 1.8,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    },
  );
}

class ReviewerLeaderboard extends StatelessWidget {
  const ReviewerLeaderboard({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviewer leaderboard', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Completed individual screening decisions (not unique articles).'),
        const SizedBox(height: 16),
        for (final reviewer in reviewers) ...[
          Row(children: [
            Expanded(child: Text(reviewer.name)),
            Text('${reviewer.completed} / ${reviewer.assigned}'),
          ]),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: reviewer.completed / reviewer.assigned, minHeight: 8),
          const SizedBox(height: 16),
        ],
      ],
    )),
  );
}
