import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_service.dart';
import '../services/project_service.dart';
import '../widgets/summary_widgets.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool loading = true;
  bool creatingBackup = false;
  String? projectId;
  String? role;
  String? error;
  String? message;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final projects = await ProjectService().getProjects();
      if (projects.isEmpty) {
        throw StateError('No accessible project found.');
      }

      final id = projects.first['id'].toString();
      final currentRole = await AdminService().getMyProjectRole(id);

      if (!mounted) return;
      setState(() {
        projectId = id;
        role = currentRole;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    final id = projectId;
    if (id == null || role != 'admin') return;

    setState(() {
      creatingBackup = true;
      error = null;
      message = null;
    });

    try {
      final backup = await AdminService().createReviewBackup(id);
      final uri = Uri.parse(backup.downloadUrl);
      final opened = await launchUrl(uri, webOnlyWindowName: '_blank');

      if (!opened) {
        throw StateError('Could not open the backup download URL.');
      }

      if (!mounted) return;
      setState(() {
        message =
            'Backup created: ${backup.filename}. The download link is valid for 15 minutes.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => creatingBackup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PageFrame(
        title: 'Administration',
        description: 'Checking project administrator access...',
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

    if (error != null) {
      return PageFrame(
        title: 'Administration',
        description: 'Unable to load administrator controls.',
        children: [
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }

    if (role != 'admin') {
      return const PageFrame(
        title: 'Administration',
        description: 'Project administrator controls.',
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'You do not have administrator access to this project.',
              ),
            ),
          ),
        ],
      );
    }

    return PageFrame(
      title: 'Administration',
      description: 'C. elegans review project administration.',
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project administrator',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Your administrator privileges apply only to this review project. They do not grant global Supabase or PostgreSQL superuser access.',
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
                const Text(
                  'Review application backup',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Creates a downloadable JSON backup containing the C. elegans review project, members, articles, assignments, screening decisions, conflict messages, and conflict resolutions. Supabase Auth accounts, platform tables, and unrelated projects are excluded.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: creatingBackup ? null : _createBackup,
                  icon: creatingBackup
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    creatingBackup ? 'Creating backup...' : 'Create backup',
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
