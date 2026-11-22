import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _client
        .from('projects')
        .select('id, title')
        .order('title');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getProjectMembers(
      String projectId,
      ) async {
    final response = await _client
        .from('project_members')
        .select('user_id, display_name')
        .eq('project_id', projectId)
        .order('display_name');

    return List<Map<String, dynamic>>.from(response);
  }
}
