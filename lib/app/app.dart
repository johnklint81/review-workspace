import 'package:material_ui/material_ui.dart';
import '../screens/pages.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/admin_page.dart';
import '../services/admin_service.dart';
import '../services/project_service.dart';
import '../screens/model_characterization_page.dart';

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

  bool checkingAdmin = true;
  bool isAdmin = false;

  static const baseTitles = [
    'Dashboard',
    'Import',
    'Articles',
    'Conflicts',
    'Statistics',
    'Model characterization',
  ];

  static const baseIcons = [
    Icons.dashboard_outlined,
    Icons.upload_file_outlined,
    Icons.article_outlined,
    Icons.forum_outlined,
    Icons.bar_chart_outlined,
    Icons.science_outlined,
  ];

  List<String> get titles => [...baseTitles, if (isAdmin) 'Administration'];

  List<IconData> get icons => [
    ...baseIcons,
    if (isAdmin) Icons.admin_panel_settings_outlined,
  ];

  Widget get page => switch (selected) {
    0 => const DashboardPage(),
    1 => const ImportPage(),
    2 => const ArticlesPage(),
    3 => const ConflictsPage(),
    4 => const StatisticsPage(),
    5 => const ModelCharacterizationPage(),
    6 when isAdmin => const AdminPage(),
    _ => const DashboardPage(),
  };

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
  }

  Future<void> _loadAdminAccess() async {
    try {
      final projects = await ProjectService().getProjects();

      if (projects.isEmpty) {
        if (!mounted) return;
        setState(() => checkingAdmin = false);
        return;
      }

      final projectId = projects.first['id'].toString();

      final role = await AdminService().getMyProjectRole(projectId);

      if (!mounted) return;

      setState(() {
        isAdmin = role == 'admin';
        checkingAdmin = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isAdmin = false;
        checkingAdmin = false;
      });
    }
  }

  void _selectPage(int index) {
    if (index >= titles.length) {
      index = 0;
    }

    setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Workspace',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text(
                  checkingAdmin
                      ? 'Loading...'
                      : isAdmin
                      ? 'Administrator'
                      : 'Reviewer',
                ),
              ),
            ),
          ),
        ],
      ),

      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    const ListTile(title: Text('Navigation')),
                    for (var i = 0; i < titles.length; i++)
                      ListTile(
                        leading: Icon(icons[i]),
                        title: Text(titles[i]),
                        selected: i == selected,
                        onTap: () {
                          _selectPage(i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),

      body: Row(
        children: [
          if (wide)
            NavigationRail(
              backgroundColor: Colors.white,
              extended: width >= 1100,
              selectedIndex: selected,
              onDestinationSelected: _selectPage,
              destinations: [
                for (var i = 0; i < titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(titles[i]),
                  ),
              ],
            ),
          Expanded(child: page),
        ],
      ),
    );
  }
}
