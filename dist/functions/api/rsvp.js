const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  },
});

export async function onRequestPost({ request, env }) {
  const origin = request.headers.get('Origin');
  if (origin && origin !== new URL(request.url).origin) {
    return json({ error: 'This request could not be accepted.' }, 403);
  }

  const contentType = request.headers.get('Content-Type') || '';
  if (!contentType.toLowerCase().includes('application/json')) {
    return json({ error: 'Please submit the RSVP form.' }, 415);
  }

  let payload;
  try {
    const body = await request.text();
    if (body.length > 4096) {
      return json({ error: 'That RSVP is too long.' }, 413);
    }
    payload = JSON.parse(body);
  } catch {
    return json({ error: 'The RSVP details could not be read.' }, 400);
  }

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return json({ error: 'The RSVP details could not be read.' }, 400);
  }

  // Quietly accept automated submissions caught by the form's honeypot.
  if (typeof payload.website === 'string' && payload.website.trim()) {
    return json({ ok: true }, 201);
  }

  const name = typeof payload.name === 'string' ? payload.name.trim() : '';
  const costume = typeof payload.costume === 'string' ? payload.costume.trim() : '';
  if (!name || !costume || name.length > 80 || costume.length > 80) {
    return json({ error: 'Add your name and costume (80 characters max each).' }, 400);
  }

  if (!env.RSVP_DB) {
    return json({ error: 'The RSVP book is not connected yet. Please try again later.' }, 503);
  }

  try {
    await env.RSVP_DB.prepare(
      'INSERT INTO rsvps (name, costume) VALUES (?, ?)',
    ).bind(name, costume).run();
    return json({ ok: true }, 201);
  } catch {
    return json({ error: 'The RSVP could not be saved. Please try again later.' }, 503);
  }
}

export async function onRequest(context) {
  if (context.request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { Allow: 'POST, OPTIONS' } });
  }
  return json({ error: 'Method not allowed.' }, 405);
}
