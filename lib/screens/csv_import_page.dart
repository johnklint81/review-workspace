import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/summary_widgets.dart';

class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  String? fileName;
  String? error;
  List<String> headers = [];
  List<List<String>> records = [];
  final Map<String, String?> mapping = {};

  bool _isPicking = false;
  int _previewVersion = 0;

  static const _maxPreviewBytes = 10 * 1024 * 1024;

  static const fields = <String, String>{
    'id': 'Article ID',
    'title': 'Title',
    'doi': 'DOI',
    'reviewer': 'Reviewer',
    'decision': 'Decision',
    'timestamp': 'Screening timestamp',
  };

  Future<void> pickFile() async {
    if (_isPicking || !mounted) return;

    setState(() {
      _isPicking = true;
      error = null;
    });

    try {
      // file_picker 13: static method, one nullable PlatformFile.
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      // Cancellation leaves the previous successful preview unchanged.
      if (!mounted || file == null) return;

      // Clear the previous file before reading a new selection.
      setState(() {
        fileName = null;
        headers = [];
        records = [];
        mapping.clear();
      });

      // Check the reported size before loading the contents, when available.
      final size = await file.length();
      if (!mounted) return;
      if (size != null && size > _maxPreviewBytes) {
        throw const FormatException('File exceeds the 10 MiB preview limit.');
      }

      // file_picker 13 exposes a method, not a .bytes property.
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxPreviewBytes) {
        throw const FormatException('File exceeds the 10 MiB preview limit.');
      }

      var content = utf8.decode(bytes, allowMalformed: false);
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      // Preserve identifiers such as 00123 as text.
      final parsed = Csv(dynamicTyping: false).decode(content);
      if (parsed.isEmpty) {
        throw const FormatException('CSV is empty.');
      }

      final newHeaders = parsed.first
          .map((value) => value.toString().trim())
          .toList();

      if (newHeaders.isEmpty || newHeaders.every((header) => header.isEmpty)) {
        throw const FormatException('The CSV has no column headers.');
      }
      if (newHeaders.any((header) => header.isEmpty)) {
        throw const FormatException(
          'Every column needs a header. Please name any blank headers.',
        );
      }
      if (newHeaders.toSet().length != newHeaders.length) {
        throw const FormatException(
          'Column headers must be unique. Please rename duplicate headers.',
        );
      }

      final newRecords = <List<String>>[];
      for (var i = 1; i < parsed.length; i++) {
        final row = parsed[i].map((value) => value.toString()).toList();
        if (row.every((value) => value.trim().isEmpty)) continue;
        if (row.length != newHeaders.length) {
          throw FormatException(
            'CSV record ${i + 1} has ${row.length} columns; '
            'expected ${newHeaders.length}.',
          );
        }
        newRecords.add(row);
      }

      final detected = <String, String?>{};
      for (final field in fields.keys) {
        final candidates = switch (field) {
          'id' => ['article_id', 'record_id', 'id', 'source_record_id'],
          'title' => ['title', 'article_title'],
          'doi' => ['doi'],
          'reviewer' => ['reviewer', 'reviewer_id', 'user', 'screened_by'],
          'decision' => ['decision', 'vote', 'label', 'screening_decision'],
          'timestamp' => ['timestamp', 'screened_at', 'submitted_at', 'date'],
          _ => <String>[],
        };
        final matches = newHeaders.where(
          (header) =>
              candidates.contains(header.toLowerCase().replaceAll(' ', '_')),
        );
        detected[field] = matches.isEmpty ? null : matches.first;
      }

      setState(() {
        fileName = file.name;
        headers = newHeaders;
        records = newRecords;
        mapping
          ..clear()
          ..addAll(detected);
        error = null;
        // Reset dropdown state even when reloading a file with the same name.
        _previewVersion++;
      });
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Unable to preview CSV: ${exception.message}';
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Could not open or read CSV: $exception';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Import screening results',
    description:
        'Preview and map CSV columns locally. Nothing is uploaded to the database.',
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _isPicking ? null : pickFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(_isPicking ? 'Opening CSV...' : 'Choose CSV file'),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (fileName != null) ...[
        const SizedBox(height: 16),
        Text(
          '$fileName \u00b7 ${records.length} data rows \u00b7 '
          '${headers.length} columns',
        ),
        const SizedBox(height: 16),
        Text('Column mapping', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...fields.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey('$_previewVersion-${entry.key}'),
              initialValue: mapping[entry.key],
              isExpanded: true,
              hint: const Text('Not mapped'),
              decoration: InputDecoration(
                labelText: entry.value,
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Not mapped'),
                ),
                ...headers.map(
                  (header) => DropdownMenuItem<String>(
                    value: header,
                    child: Text(header, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => mapping[entry.key] = value),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Preview (first 10 rows)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: headers
                  .map((header) => DataColumn(label: Text(header)))
                  .toList(),
              rows: records
                  .take(10)
                  .map(
                    (row) => DataRow(
                      cells: row
                          .map(
                            (value) => DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                child: Text(
                                  value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (records.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('The CSV contains column headers but no data rows.'),
        ],
        const SizedBox(height: 12),
        const Text(
          'Preview only: importing, deduplication, reviewer matching, '
          'and database writes are not enabled.',
        ),
      ],
    ],
  );
}
