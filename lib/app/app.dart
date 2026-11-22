import 'package:material_ui/material_ui.dart';
import '../screens/pages.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewWorkspaceApp extends StatelessWidget {
  const ReviewWorkspaceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Review Workspace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        ),
        home: const AuthGate(child: WorkspaceShell()),
      );
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key});
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int selected = 0;
  static const titles = ['Dashboard', 'Import', 'Articles', 'Conflicts', 'Statistics'];
  static const icons = [
    Icons.dashboard_outlined, Icons.upload_file_outlined,
    Icons.article_outlined, Icons.forum_outlined, Icons.bar_chart_outlined,
  ];

  Widget get page => switch (selected) {
        0 => const DashboardPage(),
        1 => const ImportPage(),
        2 => const ArticlesPage(),
        3 => const ConflictsPage(),
        _ => const StatisticsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Workspace', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('Demo data'))),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(
        child: SafeArea(child: ListView(children: [
          const ListTile(title: Text('Navigation')),
          for (var i = 0; i < titles.length; i++)
            ListTile(
              leading: Icon(icons[i]), title: Text(titles[i]),
              selected: i == selected,
              onTap: () { setState(() => selected = i); Navigator.pop(context); },
            ),
        ])),
      ),
      body: Row(children: [
        if (wide) NavigationRail(
          backgroundColor: Colors.white,
          extended: width >= 1100,
          selectedIndex: selected,
          onDestinationSelected: (index) => setState(() => selected = index),
          destinations: [
            for (var i = 0; i < titles.length; i++)
              NavigationRailDestination(icon: Icon(icons[i]), label: Text(titles[i])),
          ],
        ),
        Expanded(child: page),
      ]),
    );
  }
}
