// Minimal CORS proxy so the Flutter **web** build can read the NPDC portal.
//
//   dart run tool/ncpor_proxy.dart            # listens on 127.0.0.1:8100
//   NCPOR_PROXY_PORT=9000 dart run tool/ncpor_proxy.dart
//
// Then launch the app against it:
//
//   flutter run -d web-server --web-port 8099 --web-hostname 127.0.0.1 \
//     --dart-define=NCPOR_PROXY=http://127.0.0.1:8100/?url=
//
// Why this exists: data.ncpor.res.in answers OPTIONS with 200 but sends no
// Access-Control-* headers at all, so a browser refuses to read the
// response. This proxy fetches server-side and adds the CORS headers.
//
// It is deliberately NOT an open proxy: only data.ncpor.res.in is
// forwarded, and only over https. Point it at loopback and keep it out of
// any public deployment — in production use a Supabase Edge Function or
// your own backend instead.
import 'dart:io';

/// Only this host may be reached through the proxy.
const _allowedHost = 'data.ncpor.res.in';

Future<void> main(List<String> args) async {
  final port =
      int.tryParse(Platform.environment['NCPOR_PROXY_PORT'] ?? '') ?? 8100;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('NPDC CORS proxy → http://127.0.0.1:$port/?url=<encoded>');

  await for (final request in server) {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.set('Access-Control-Max-Age', '86400');

    if (request.method.toUpperCase() == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      continue;
    }

    final target = request.uri.queryParameters['url'];
    if (target == null || target.isEmpty) {
      response
        ..statusCode = HttpStatus.badRequest
        ..write('Missing ?url= target');
      await response.close();
      continue;
    }

    final Uri uri;
    try {
      uri = Uri.parse(target);
    } on FormatException catch (e) {
      response
        ..statusCode = HttpStatus.badRequest
        ..write('Malformed target: ${e.message}');
      await response.close();
      continue;
    }

    if (uri.scheme != 'https' || uri.host != _allowedHost) {
      response
        ..statusCode = HttpStatus.forbidden
        ..write('Only https://$_allowedHost may be proxied');
      await response.close();
      continue;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final upstreamRequest = await client.getUrl(uri);
      upstreamRequest.followRedirects = true;
      final upstream = await upstreamRequest.close();

      final body = await upstream.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );

      final contentType = upstream.headers.contentType;
      if (contentType != null) {
        response.headers.contentType = contentType;
      }

      response
        ..statusCode = upstream.statusCode
        ..add(body);
      await response.close();
    } catch (e) {
      response
        ..statusCode = HttpStatus.badGateway
        ..write('Upstream error: $e');
      await response.close();
    } finally {
      client.close(force: true);
    }
  }
}
