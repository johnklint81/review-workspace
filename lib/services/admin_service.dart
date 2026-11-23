import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> getMyProjectRole(String projectId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('project_members')
        .select('role')
        .eq('project_id', projectId)
        .eq('user_id', userId)
        .maybeSingle();

    return row?['role'] as String?;
  }

  Future<BackupDownload> createReviewBackup(String projectId) async {
    final response = await _client.functions.invoke(
      'create-review-backup',
      body: {'project_id': projectId},
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return BackupDownload(
      filename: data['filename'] as String,
      downloadUrl: data['download_url'] as String,
    );
  }
}

class BackupDownload {
  final String filename;
  final String downloadUrl;

  const BackupDownload({required this.filename, required this.downloadUrl});
}
