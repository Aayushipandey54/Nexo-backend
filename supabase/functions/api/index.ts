import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Hono } from 'https://deno.land/x/hono@v3.4.1/mod.ts'
import { cors } from 'https://deno.land/x/hono@v3.4.1/middleware.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const app = new Hono()

// Enable CORS for frontend requests
app.use('*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization', 'apikey', 'x-client-info'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
}))

// Initialize Supabase Client using local Deno environment variables
const getSupabaseClient = () => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';
  return createClient(supabaseUrl, supabaseServiceKey);
};

// 1. GET /event-state
app.get('/event-state', async (c) => {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('event_state')
    .select('*')
    .eq('id', 1)
    .single();
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data);
});

// 2. PUT /event-state
app.put('/event-state', async (c) => {
  const supabase = getSupabaseClient();
  const body = await c.req.json();
  const { data, error } = await supabase
    .from('event_state')
    .update(body)
    .eq('id', 1)
    .select();
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data ? data[0] : null);
});

// 3. POST /verify-key
app.post('/verify-key', async (c) => {
  const supabase = getSupabaseClient();
  const { accessKey } = await c.req.json();
  const { data, error } = await supabase
    .from('teams')
    .select('*')
    .eq('access_key', accessKey.trim())
    .maybeSingle();
  if (error) return c.json({ error: error.message }, 500);
  if (!data) return c.json({ error: 'Team not found' }, 404);
  return c.json(data);
});

// 4. PUT /teams/:id
app.put('/teams/:id', async (c) => {
  const supabase = getSupabaseClient();
  const id = c.req.param('id');
  const body = await c.req.json();
  const { data, error } = await supabase
    .from('teams')
    .update(body)
    .eq('id', id)
    .select();
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data ? data[0] : null);
});

// 5. GET /teams
app.get('/teams', async (c) => {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('teams')
    .select('*')
    .order('total_score', { ascending: false });
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data || []);
});

// 6. GET /questions
app.get('/questions', async (c) => {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('mcq_questions')
    .select('*')
    .order('id', { ascending: true });
  if (error) return c.json({ error: error.message }, 500);
  
  // Parse options properly if it comes as string (should be JSONB)
  const parsed = (data || []).map((q: any) => ({
    id: q.id,
    category: q.category,
    question: q.question,
    options: typeof q.options === 'string' ? JSON.parse(q.options) : q.options,
    correctIndex: q.correct_index,
    explanation: q.explanation || ''
  }));
  return c.json(parsed);
});

// 7. POST /questions
app.post('/questions', async (c) => {
  const supabase = getSupabaseClient();
  const body = await c.req.json();
  const { id, category, question, options, correctIndex, explanation } = body;
  
  const payload = {
    category,
    question,
    options,
    correct_index: correctIndex,
    explanation: explanation || ''
  };

  if (!id || id > 10000000000) {
    const { data: inserted, error } = await supabase
      .from('mcq_questions')
      .insert([payload])
      .select();
    if (error) return c.json({ error: error.message }, 500);
    return c.json(inserted ? inserted[0] : null);
  } else {
    const { data: updated, error } = await supabase
      .from('mcq_questions')
      .update(payload)
      .eq('id', id)
      .select();
    if (error) return c.json({ error: error.message }, 500);
    return c.json(updated ? updated[0] : null);
  }
});

// 8. DELETE /questions/:id
app.delete('/questions/:id', async (c) => {
  const supabase = getSupabaseClient();
  const id = c.req.param('id');
  const { error } = await supabase
    .from('mcq_questions')
    .delete()
    .eq('id', parseInt(id));
  if (error) return c.json({ error: error.message }, 500);
  return c.json({ success: true });
});

// 9. GET /wordle-words
app.get('/wordle-words', async (c) => {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('wordle_words')
    .select('*')
    .order('id', { ascending: true });
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data || []);
});

// 10. POST /wordle-words
app.post('/wordle-words', async (c) => {
  const supabase = getSupabaseClient();
  const body = await c.req.json();
  const { id, word, hint, category } = body;

  const payload = {
    word: word.toUpperCase(),
    hint,
    category
  };

  if (!id || id > 10000000000) {
    const { data: inserted, error } = await supabase
      .from('wordle_words')
      .insert([payload])
      .select();
    if (error) return c.json({ error: error.message }, 500);
    return c.json(inserted ? inserted[0] : null);
  } else {
    const { data: updated, error } = await supabase
      .from('wordle_words')
      .update(payload)
      .eq('id', id)
      .select();
    if (error) return c.json({ error: error.message }, 500);
    return c.json(updated ? updated[0] : null);
  }
});

// 11. DELETE /wordle-words/:id
app.delete('/wordle-words/:id', async (c) => {
  const supabase = getSupabaseClient();
  const id = c.req.param('id');
  const { error } = await supabase
    .from('wordle_words')
    .delete()
    .eq('id', parseInt(id));
  if (error) return c.json({ error: error.message }, 500);
  return c.json({ success: true });
});

// 12. POST /submissions
app.post('/submissions', async (c) => {
  const supabase = getSupabaseClient();
  const body = await c.req.json();
  const { teamId, teamName, repoUrl } = body;

  const payload = {
    team_id: teamId,
    team_name: teamName,
    mission: 3,
    repo_url: repoUrl,
    score: 1200,
    status: 'PENDING'
  };

  const { data, error } = await supabase
    .from('submissions')
    .insert([payload])
    .select();
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data ? data[0] : null);
});

// 13. GET /submissions
app.get('/submissions', async (c) => {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('submissions')
    .select('*')
    .order('submitted_at', { ascending: false });
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data || []);
});

// 14. PUT /submissions/:id
app.put('/submissions/:id', async (c) => {
  const supabase = getSupabaseClient();
  const id = c.req.param('id');
  const { status } = await c.req.json();
  const { data, error } = await supabase
    .from('submissions')
    .update({ status })
    .eq('id', id)
    .select();
  if (error) return c.json({ error: error.message }, 500);
  return c.json(data ? data[0] : null);
});

// Start Deno HTTP server
serve(app.fetch);
