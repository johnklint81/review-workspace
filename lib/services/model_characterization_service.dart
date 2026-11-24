import 'package:supabase_flutter/supabase_flutter.dart';

class ModelCharacterizationService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> articles(String projectId) async {
    final rows = await client.from('articles')
        .select('id,title,doi').eq('project_id', projectId).order('title');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> myExtraction(String projectId, String articleId) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in required');
    return await client.from('model_characterizations').select()
        .eq('project_id', projectId).eq('article_id', articleId)
        .eq('extractor_id', uid).maybeSingle();
  }

  Future<void> save(String projectId, String articleId,
      Map<String, dynamic> fields, {required bool complete}) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in required');
    await client.from('model_characterizations').upsert({
      'project_id': projectId,
      'article_id': articleId,
      'extractor_id': uid,
      ...fields,
      'status': complete ? 'complete' : 'draft',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'project_id,article_id,extractor_id');
  }
}
