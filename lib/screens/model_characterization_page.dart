import 'package:material_ui/material_ui.dart';
import '../services/project_service.dart';
import '../services/model_characterization_service.dart';
import '../widgets/summary_widgets.dart';

class ModelCharacterizationPage extends StatefulWidget {
  const ModelCharacterizationPage({super.key});
  @override
  State<ModelCharacterizationPage> createState() =>
      _ModelCharacterizationPageState();
}

class _ModelCharacterizationPageState extends State<ModelCharacterizationPage> {
  final service = ModelCharacterizationService();
  final components = <String>{};
  final provenance = <String>{};
  final fields = <String, TextEditingController>{
    for (final key in [
      'coupling_architecture',
      'parameter_notes',
      'calibration_notes',
      'validation_notes',
      'code_availability',
      'data_availability',
      'parameter_documentation',
      'workflow_reproducibility',
      'evidence_notes',
    ])
      key: TextEditingController(),
  };
  static const componentOptions = [
    'Neurons',
    'Muscles',
    'Body mechanics',
    'Sensory system',
    'Environment',
    'Other',
  ];
  static const provenanceOptions = [
    'Measured',
    'Estimated',
    'Fitted',
    'Assumed',
    'ML-derived',
    'Unclear',
  ];
  String feedback = 'not_assessed';
  String independent = 'unclear';
  String? projectId, articleId;
  List<Map<String, dynamic>> articles = [];
  bool busy = true, saving = false;
  int _selectionRequest = 0;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    loadProject();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadProject() async {
    try {
      final projects = await ProjectService().getProjects();
      if (projects.isEmpty) throw StateError('No accessible project');
      final id = projects.first['id'].toString();
      final rows = await service.articles(id);
      if (!mounted) return;
      setState(() {
        projectId = id;
        articles = rows;
        busy = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = '$e';
      });
    }
  }

  Future<void> selectArticle(String id) async {
    final request = ++_selectionRequest;
    setState(() {
      busy = true;
      articleId = null;
      notice = null;
      error = null;
    });
    try {
      final row = await service.myExtraction(projectId!, id);
      if (!mounted || request != _selectionRequest) return;
      for (final entry in fields.entries) {
        entry.value.text = row?[entry.key]?.toString() ?? '';
      }
      setState(() {
        articleId = id;
        components
          ..clear()
          ..addAll(
            (row?['components'] as List? ?? []).map((e) => e.toString()),
          );
        provenance
          ..clear()
          ..addAll(
            (row?['parameter_provenance'] as List? ?? []).map(
              (e) => e.toString(),
            ),
          );
        feedback = row?['feedback_loop']?.toString() ?? 'not_assessed';
        independent = row?['independent_validation']?.toString() ?? 'unclear';
        busy = false;
      });
    } catch (e) {
      if (!mounted || request != _selectionRequest) return;
      setState(() {
        busy = false;
        error = '$e';
      });
    }
  }

  Future<void> save({required bool complete}) async {
    if (projectId == null || articleId == null || busy || saving) return;
    setState(() {
      saving = true;
      error = null;
      notice = null;
    });
    try {
      await service.save(projectId!, articleId!, {
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        'components': components.toList()..sort(),
        'parameter_provenance': provenance.toList()..sort(),
        'feedback_loop': feedback,
        'independent_validation': independent,
      }, complete: complete);
      if (!mounted) return;
      setState(() {
        notice = complete ? 'Marked complete.' : 'Draft saved.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget field(String key, String label, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: fields[key],
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    ),
  );

  Widget chips(String title, List<String> options, Set<String> chosen) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: chosen.contains(option),
                  onSelected: (yes) => setState(() {
                    if (yes) {
                      chosen.add(option);
                    } else {
                      chosen.remove(option);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Model characterization',
    description:
        'Structured extraction for included C. elegans modeling studies.',
    children: [
      if (busy) const Center(child: CircularProgressIndicator()),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (!busy) ...[
        if (articles.isEmpty)
          const Text(
            'No articles available. Import and assess articles first.',
          ),
        if (articles.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('article-picker-$articleId'),
            initialValue: articleId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Article',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in articles)
                DropdownMenuItem(
                  value: a['id'].toString(),
                  child: Text(
                    a['title']?.toString() ?? 'Untitled',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) selectArticle(value);
                  },
          ),
        if (articleId != null) ...[
          const SizedBox(height: 20),
          chips('Represented components', componentOptions, components),
          field(
            'coupling_architecture',
            'Coupling architecture',
            hint:
                'Describe neural, muscle, body, sensory, and environment interactions.',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('feedback-$articleId'),
            initialValue: feedback,
            decoration: const InputDecoration(
              labelText: 'Feedback loop classification',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'not_assessed',
                child: Text('Not assessed'),
              ),
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'open_loop', child: Text('Open loop')),
              DropdownMenuItem(
                value: 'partial',
                child: Text('Partial feedback'),
              ),
              DropdownMenuItem(
                value: 'closed_loop',
                child: Text('Closed loop'),
              ),
              DropdownMenuItem(value: 'unclear', child: Text('Unclear')),
            ],
            onChanged: (v) => setState(() => feedback = v ?? feedback),
          ),
          const SizedBox(height: 16),
          chips('Parameter provenance', provenanceOptions, provenance),
          field(
            'parameter_notes',
            'Parameter provenance details',
            hint:
                'Which parameters are measured, fitted, assumed, or ML-derived?',
          ),
          field('calibration_notes', 'Calibration methods and datasets'),
          field(
            'validation_notes',
            'Experimental validation and predictive evaluation',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('independent-$articleId'),
            initialValue: independent,
            decoration: const InputDecoration(
              labelText: 'Independent validation data',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'yes', child: Text('Yes')),
              DropdownMenuItem(value: 'no', child: Text('No')),
              DropdownMenuItem(value: 'unclear', child: Text('Unclear')),
              DropdownMenuItem(
                value: 'not_applicable',
                child: Text('Not applicable'),
              ),
            ],
            onChanged: (v) => setState(() => independent = v ?? independent),
          ),
          const SizedBox(height: 16),
          field('code_availability', 'Code availability / URL'),
          field('data_availability', 'Dataset availability / URL'),
          field('parameter_documentation', 'Parameter documentation'),
          field('workflow_reproducibility', 'Workflow reproducibility'),
          field(
            'evidence_notes',
            'Evidence notes and page references',
            hint: 'Cite paper sections/pages supporting each assessment.',
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: saving ? null : () => save(complete: false),
                child: const Text('Save draft'),
              ),
              FilledButton(
                onPressed: saving ? null : () => save(complete: true),
                child: const Text('Mark complete'),
              ),
            ],
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(notice!),
            ),
        ],
      ],
    ],
  );
}
