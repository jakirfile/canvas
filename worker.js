const SESSION_COOKIE = 'session';
const SESSION_TTL_SECONDS = 60 * 60 * 12;
const encoder = new TextEncoder();

const loginPage = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Session access</title>
  <style>
    *{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f3f5f9;color:#172033;font:16px/1.5 system-ui,sans-serif}
    main{width:min(420px,calc(100% - 32px));padding:32px;border-radius:16px;background:#fff;box-shadow:0 12px 40px #18294a18}
    h1{margin:0 0 8px;font-size:24px}p{margin:0 0 22px;color:#58657a}label{display:block;margin-bottom:7px;font-weight:600}
    input,button{width:100%;height:46px;border-radius:8px;font:inherit}input{padding:0 12px;border:1px solid #cbd3df}
    button{margin-top:14px;border:0;background:#2563eb;color:#fff;font-weight:700;cursor:pointer}button:disabled{opacity:.6;cursor:wait}
    #message{min-height:24px;margin-top:12px;color:#b42318;font-size:14px}
  </style>
</head>
<body>
  <main>
    <h1>Enter session code</h1>
    <p>Enter your access code to open the dashboard.</p>
    <form id="form">
      <label for="code">Session code</label>
      <input id="code" name="code" type="password" autocomplete="one-time-code" required autofocus>
      <button id="submit" type="submit">Continue</button>
      <div id="message" role="status" aria-live="polite"></div>
    </form>
  </main>
  <script>
    const form=document.querySelector('#form');
    const button=document.querySelector('#submit');
    const message=document.querySelector('#message');
    form.addEventListener('submit',async event=>{
      event.preventDefault();
      button.disabled=true;
      message.textContent='';
      try{
        const response=await fetch('/__session/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({code:document.querySelector('#code').value})});
        if(!response.ok)throw new Error((await response.text())||'Unable to verify the session code.');
        location.replace('/');
      }catch(error){message.textContent=error.message}
      finally{button.disabled=false}
    });
  </script>
</body>
</html>`;

function response(body, status = 200, headers = {}) {
  return new Response(body, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...headers,
    },
  });
}

function bytesToBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64UrlToBytes(value) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - base64.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function sign(value, secret) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(value));
  return bytesToBase64Url(new Uint8Array(signature));
}

function constantTimeEqual(left, right) {
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  let difference = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] || 0) ^ (rightBytes[index] || 0);
  }
  return difference === 0;
}

function getCookie(request, name) {
  const cookies = request.headers.get('Cookie') || '';
  for (const cookie of cookies.split(';')) {
    const separator = cookie.indexOf('=');
    if (separator < 0) continue;
    if (cookie.slice(0, separator).trim() === name) {
      return cookie.slice(separator + 1).trim();
    }
  }
  return '';
}

async function hasValidSession(request, signingSecret) {
  const token = getCookie(request, SESSION_COOKIE);
  const separator = token.indexOf('.');
  if (!token || separator < 1) return false;

  const payload = token.slice(0, separator);
  const signature = token.slice(separator + 1);
  const expected = await sign(payload, signingSecret);
  if (!constantTimeEqual(signature, expected)) return false;

  try {
    const claims = JSON.parse(new TextDecoder().decode(base64UrlToBytes(payload)));
    return Number.isInteger(claims.exp) && claims.exp > Math.floor(Date.now() / 1000);
  } catch {
    return false;
  }
}

async function createSessionCookie(signingSecret) {
  const payload = bytesToBase64Url(
    encoder.encode(JSON.stringify({
      exp: Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS,
    })),
  );
  const signature = await sign(payload, signingSecret);
  return `${SESSION_COOKIE}=${payload}.${signature}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${SESSION_TTL_SECONDS}`;
}

async function handleLogin(request, SESSION_CODE, GITHUB_TOKEN) {
  let body;
  try {
    body = await request.json();
  } catch {
    return response('A valid JSON request is required.', 400);
  }

  if (!body || typeof body !== 'object' || typeof body.code !== 'string'
    || !constantTimeEqual(body.code, SESSION_CODE)) {
    return response('Invalid session code.', 401);
  }

  return response(null, 204, {
    'Set-Cookie': await createSessionCookie(GITHUB_TOKEN),
  });
}

function handleLogout() {
  return new Response(null, {
    status: 303,
    headers: {
      'Location': '/',
      'Cache-Control': 'no-store',
      'Set-Cookie': `${SESSION_COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`,
    },
  });
}

async function fetchAsset(request, ASSETS) {
  if (!ASSETS || typeof ASSETS.fetch !== 'function') {
    return response('Cloudflare ASSETS binding is not configured.', 503);
  }

  try {
    const assetResponse = await ASSETS.fetch(request);
    if (assetResponse.status === 404) {
      return response('Asset not found.', 404, {
        'Content-Type': 'text/plain; charset=utf-8',
      });
    }

    const headers = new Headers(assetResponse.headers);
    headers.set('Cache-Control', 'private, no-store');
    headers.set('X-Content-Type-Options', 'nosniff');
    return new Response(assetResponse.body, {
      status: assetResponse.status,
      statusText: assetResponse.statusText,
      headers,
    });
  } catch (error) {
    console.error('Dashboard asset request failed:', error);
    return response('Unable to load the dashboard.', 502);
  }
}

async function handleRequest(request, env) {
  const { GITHUB_TOKEN, SESSION_CODE, ASSETS } = env;
  if (!GITHUB_TOKEN || !SESSION_CODE) {
    return response('GITHUB_TOKEN and SESSION_CODE secrets are required.', 503);
  }

  const url = new URL(request.url);
  if (url.pathname === '/__session/login' && request.method === 'POST') {
    return handleLogin(request, SESSION_CODE, GITHUB_TOKEN);
  }
  if (url.pathname === '/__session/logout' && request.method === 'GET') {
    return handleLogout();
  }

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return response('Method not allowed.', 405, { Allow: 'GET, HEAD' });
  }

  if (!await hasValidSession(request, GITHUB_TOKEN)) {
    return response(loginPage, 200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
      'Referrer-Policy': 'no-referrer',
    });
  }

  return fetchAsset(request, ASSETS);
}

export default {
  fetch(request, env) {
    return handleRequest(request, env);
  },
};
