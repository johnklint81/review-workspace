import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_SERVICE_ROLE_KEY is not configured');
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'Missing authentication' }, 401);
  }

  const accessToken = authHeader.substring('Bearer '.length);

  // Validate the caller's session with the normal authenticated API key.
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;

  if (userError || !user) {
    return json({ error: 'Invalid or expired session' }, 401);
  }

  let body: { project_id?: string } = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Request body must be JSON' }, 400);
  }

  const projectId = body.project_id;
  if (!projectId) {
    return json({ error: 'project_id is required' }, 400);
  }

  // Explicitly enforce the project-scoped admin role. This function uses the
  // service role below, so this check must happen before any privileged query.
  const { data: membership, error: membershipError } = await admin
    .from('project_members')
    .select('project_id, user_id, display_name, role')
    .eq('project_id', projectId)
    .eq('user_id', user.id)
    .maybeSingle();

  if (membershipError) {
    return json({ error: membershipError.message }, 500);
  }

  if (!membership || membership.role !== 'admin') {
    return json({ error: 'Project administrator access required' }, 403);
  }

  const [project, members, articles, assignments, decisions, messages, resolutions, characterizations] =
    await Promise.all([
      admin.from('projects').select('id, title, created_at').eq('id', projectId).single(),
      admin.from('project_members')
        .select('project_id, user_id, display_name, role, created_at')
        .eq('project_id', projectId),
      admin.from('articles')
        .select('id, project_id, source, source_record_id, doi, title, authors, publication_year, created_at')
        .eq('project_id', projectId),
      admin.from('article_assignments')
        .select('project_id, article_id, reviewer_id, assigned_at')
        .eq('project_id', projectId),
      admin.from('screening_decisions')
        .select('id, project_id, article_id, reviewer_id, vote, submitted_at, source_import_id')
        .eq('project_id', projectId),
      admin.from('conflict_messages')
        .select('id, project_id, article_id, author_id, body, created_at')
        .eq('project_id', projectId),
      admin.from('conflict_resolutions')
        .select('id, project_id, article_id, method, final_vote, decided_by, rationale, decided_at')
        .eq('project_id', projectId),
      admin.from('model_characterizations')
        .select('*')
        .eq('project_id', projectId),
    ]);

  const results = [project, members, articles, assignments, decisions, messages, resolutions, characterizations];
  const firstError = results.find((result) => result.error);
  if (firstError?.error) {
    return json({ error: firstError.error.message }, 500);
  }

  const exportedAt = new Date().toISOString();
  const backup = {
    backup_version: 2,
    application: 'Review Workspace',
    project: project.data,
    exported_at: exportedAt,
    exported_by: user.id,
    tables: {
      projects: project.data ? [project.data] : [],
      project_members: members.data ?? [],
      articles: articles.data ?? [],
      article_assignments: assignments.data ?? [],
      screening_decisions: decisions.data ?? [],
      conflict_messages: messages.data ?? [],
      conflict_resolutions: resolutions.data ?? [],
      model_characterizations: characterizations.data ?? [],
    },
    excluded_from_this_backup: [
      'Supabase Auth users and credentials',
      'Supabase Storage objects outside review-backups',
      'Supabase platform/system tables',
    ],
  };

  const payload = JSON.stringify(backup, null, 2);
  const filename = `c-elegans-review-backup-${exportedAt.replace(/[:.]/g, '-')}.json`;

    const { data: upload, error: uploadError } = await admin.storage
      .from('review-backups')
      .upload(
        `${projectId}/${filename}`,
        new Blob([payload], { type: 'application/json' }),
        {
          contentType: 'application/json',
          upsert: false,
        },
      );

    if (uploadError) {
      return json({ error: uploadError.message }, 500);
    }

    const { data: signed, error: signedError } = await admin.storage
      .from('review-backups')
      .createSignedUrl(
        upload.path,
        60 * 15,
        {
          download: filename,
        },
      );

    if (signedError || !signed?.signedUrl) {
      return json({
        error: signedError?.message ?? 'Could not create download URL',
      }, 500);
    }

    return json({
      filename,
      exported_at: exportedAt,
      download_url: signed.signedUrl,
      project_id: projectId,
    });
});