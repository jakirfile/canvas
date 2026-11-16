import { describe, expect, it, vi } from 'vitest';
import worker from './worker.js';

const SESSION_CODE = 'test-code';
const GITHUB_TOKEN = 'test-session-signing-secret';

function createEnv(assetsFetch = vi.fn(async () => new Response('asset'))) {
  return {
    SESSION_CODE,
    GITHUB_TOKEN,
    ASSETS: { fetch: assetsFetch },
  };
}

describe('Cloudflare Worker session gate', () => {
  it('does not fetch site assets before a session is established', async () => {
    const assetsFetch = vi.fn();
    const response = await worker.fetch(
      new Request('https://canvas.example/'),
      createEnv(assetsFetch),
    );

    expect(response.status).toBe(200);
    expect(await response.text()).toContain('Enter session code');
    expect(assetsFetch).not.toHaveBeenCalled();
  });

  it('serves the requested static asset after login', async () => {
    const assetsFetch = vi.fn(async (request) => new Response(new URL(request.url).pathname));
    const env = createEnv(assetsFetch);
    const login = await worker.fetch(
      new Request('https://canvas.example/__session/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: SESSION_CODE }),
      }),
      env,
    );
    const cookie = login.headers.get('Set-Cookie').split(';', 1)[0];

    const asset = await worker.fetch(
      new Request('https://canvas.example/_next/static/app.js', {
        headers: { Cookie: cookie },
      }),
      env,
    );

    expect(login.status).toBe(204);
    expect(asset.status).toBe(200);
    expect(await asset.text()).toBe('/_next/static/app.js');
    expect(assetsFetch).toHaveBeenCalledTimes(1);
  });
});
