// AROHA — NPDC telemetry proxy (Supabase Edge Function)
//
// Why this exists
// ---------------
// data.ncpor.res.in answers OPTIONS with 200 but sends no `Access-Control-*`
// headers, so a browser cannot read it cross-origin. The Flutter web build
// therefore cannot fetch live polar telemetry directly. This function fetches
// server-side, where CORS does not apply, and hands the bytes back with
// permissive CORS headers.
//
// This replaces the loopback dev proxy in `tool/ncpor_proxy.dart`, which only
// listens on 127.0.0.1 and is useless to a deployed site.
//
// Usage (the app builds `<prefix><percent-encoded target>`):
//   GET /functions/v1/npdc-proxy?url=https%3A%2F%2Fdata.ncpor.res.in%2Fmaitri%2Ftemp
//
// Security
// --------
// This is a public, unauthenticated endpoint, so it is deliberately NOT an open
// proxy. Only `https://data.ncpor.res.in` may be fetched; anything else is
// refused with 403. That closes the obvious SSRF and open-redirect/abuse paths
// (the function has no credentials to leak, but it does have the project's
// egress network position, so an unrestricted forwarder would be a liability).
//
// The response is passed through byte-for-byte with only the upstream
// content-type preserved, so the app's HTML scraping in
// `lib/services/ncpor_data_source.dart` keeps working unchanged.

const ALLOWED_HOST = "data.ncpor.res.in";
const UPSTREAM_TIMEOUT_MS = 15_000;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

function text(status: number, body: string): Response {
  return new Response(body, {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "text/plain; charset=utf-8" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "GET") {
    return text(405, "Only GET is supported");
  }

  const raw = new URL(req.url).searchParams.get("url");
  if (!raw) {
    return text(400, "Missing ?url= target");
  }

  let target: URL;
  try {
    target = new URL(raw);
  } catch {
    return text(400, "Malformed target URL");
  }

  // Allowlist check. Compare hostname exactly — a suffix test would let
  // `evil-data.ncpor.res.in` through.
  if (target.protocol !== "https:" || target.hostname !== ALLOWED_HOST) {
    return text(403, `Only https://${ALLOWED_HOST} may be proxied`);
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const upstream = await fetch(target.toString(), {
      signal: controller.signal,
      redirect: "follow",
      headers: {
        // The portal is a plain public site; identify ourselves honestly.
        "User-Agent": "AROHA-Polar-Expedition-Command/1.0 (+NCPOR telemetry reader)",
        Accept: "text/html,application/xhtml+xml",
      },
    });

    const body = await upstream.text();

    return new Response(body, {
      status: upstream.status,
      headers: {
        ...CORS_HEADERS,
        "Content-Type":
          upstream.headers.get("content-type") ?? "text/html; charset=utf-8",
        // Telemetry pages change on the order of hours, not seconds.
        "Cache-Control": "public, max-age=300",
      },
    });
  } catch (err) {
    const aborted = err instanceof Error && err.name === "AbortError";
    return text(
      aborted ? 504 : 502,
      aborted ? "Upstream timed out" : `Upstream error: ${String(err)}`,
    );
  } finally {
    clearTimeout(timer);
  }
});
