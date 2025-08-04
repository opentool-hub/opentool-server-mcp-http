/// Modify from https://github.com/leehack/mcp_dart/blob/main/example/streamable_https/server_streamable_https.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'mcp_server.dart';

void setCorsHeaders(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*'); // Allow any origin
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, mcp-session-id, Last-Event-ID, Authorization');
  response.headers.set('Access-Control-Allow-Credentials', 'true');
  response.headers.set('Access-Control-Max-Age', '86400'); // 24 hours
  response.headers.set('Access-Control-Expose-Headers', 'mcp-session-id');
}

Future<void> startMcpHttpServer({String host = "0.0.0.0", int port = 3000, Future<void> Function()? onPostStart}) async {
  final transports = <String, StreamableHTTPServerTransport>{};

  final server = await HttpServer.bind(host, port);
  print('MCP HTTP Server listening on http://${server.address.host}/${server.port}');

  if(onPostStart != null) await onPostStart();

  await for (final request in server) {
    // Apply CORS headers to all responses
    setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      // Handle CORS preflight request
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    if (request.uri.path != '/mcp') {
      // Not an MCP endpoint
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
      continue;
    }

    switch (request.method) {
      case 'OPTIONS':
        // Handle preflight requests
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        break;
      case 'POST':
        await handlePostRequest(request, transports);
        break;
      case 'GET':
        await handleGetRequest(request, transports);
        break;
      case 'DELETE':
        await handleDeleteRequest(request, transports);
        break;
      default:
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..headers.set(HttpHeaders.allowHeader, 'GET, POST, DELETE, OPTIONS');
        // CORS headers already applied at the top
        request.response
          ..write('Method Not Allowed')
          ..close();
    }
  }
}

// Function to check if a request is an initialization request
bool isInitializeRequest(dynamic body) {
  if (body is Map<String, dynamic> &&
      body.containsKey('method') &&
      body['method'] == 'initialize') {
    return true;
  }
  return false;
}

// Handle POST requests
Future<void> handlePostRequest(
  HttpRequest request,
  Map<String, StreamableHTTPServerTransport> transports,
) async {
  print('Received MCP request');

  try {
    // Parse the body
    final bodyBytes = await collectBytes(request);
    final bodyString = utf8.decode(bodyBytes);
    final body = jsonDecode(bodyString);

    // Check for existing session ID
    final sessionId = request.headers.value('mcp-session-id');
    StreamableHTTPServerTransport? transport;

    if (sessionId != null && transports.containsKey(sessionId)) {
      // Reuse existing transport
      transport = transports[sessionId]!;
    } else if (sessionId == null && isInitializeRequest(body)) {
      // New initialization request
      transport = StreamableHTTPServerTransport(
        options: StreamableHTTPServerTransportOptions(
          sessionIdGenerator: () => uniqueId(),
          onsessioninitialized: (sessionId) {
            print('Session initialized with ID: $sessionId');
            transports[sessionId] = transport!;
          },
        ),
      );

      // Set up onclose handler to clean up transport when closed
      transport.onclose = () {
        final sid = transport!.sessionId;
        if (sid != null && transports.containsKey(sid)) {
          print('Transport closed for session $sid, removing from transports map');
          transports.remove(sid);
        }
      };

      // Connect the transport to the MCP server BEFORE handling the request
      final server = getServer();
      await server.connect(transport);

      print('Handling initialization request for a new session');
      await transport.handleRequest(request, body);
      return; // Already handled
    } else {
      // Invalid request - no session ID or not initialization request
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      // Apply CORS headers to this specific response
      setCorsHeaders(request.response);
      request.response
        ..write(jsonEncode({
          'jsonrpc': '2.0',
          'error': {
            'code': -32000,
            'message': 'Bad Request: No valid session ID provided',
          },
          'id': null,
        }))
        ..close();
      return;
    }

    // Handle the request with existing transport
    await transport.handleRequest(request, body);
  } catch (error) {
    print('Error handling MCP request: $error');
    // Check if headers are already sent
    bool headersSent = false;
    try {
      headersSent = request.response.headers.contentType
          .toString()
          .startsWith('text/event-stream');
    } catch (_) {
      // Ignore errors when checking headers
    }

    if (!headersSent) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      // Apply CORS headers
      setCorsHeaders(request.response);
      request.response
        ..write(jsonEncode({
          'jsonrpc': '2.0',
          'error': {
            'code': -32603,
            'message': 'Internal server error',
          },
          'id': null,
        }))
        ..close();
    }
  }
}

// Handle GET requests for SSE streams
Future<void> handleGetRequest(
  HttpRequest request,
  Map<String, StreamableHTTPServerTransport> transports,
) async {
  final sessionId = request.headers.value('mcp-session-id');
  if (sessionId == null || !transports.containsKey(sessionId)) {
    request.response.statusCode = HttpStatus.badRequest;
    // Apply CORS headers
    setCorsHeaders(request.response);
    request.response
      ..write('Invalid or missing session ID')
      ..close();
    return;
  }

  // Check for Last-Event-ID header for resumability
  final lastEventId = request.headers.value('Last-Event-ID');
  if (lastEventId != null) {
    print('Client reconnecting with Last-Event-ID: $lastEventId');
  } else {
    print('Establishing new SSE stream for session $sessionId');
  }

  final transport = transports[sessionId]!;
  await transport.handleRequest(request);
}

// Handle DELETE requests for session termination
Future<void> handleDeleteRequest(
  HttpRequest request,
  Map<String, StreamableHTTPServerTransport> transports,
) async {
  final sessionId = request.headers.value('mcp-session-id');
  if (sessionId == null || !transports.containsKey(sessionId)) {
    request.response.statusCode = HttpStatus.badRequest;
    // Apply CORS headers
    setCorsHeaders(request.response);
    request.response
      ..write('Invalid or missing session ID')
      ..close();
    return;
  }

  print('Received session termination request for session $sessionId');

  try {
    final transport = transports[sessionId]!;
    await transport.handleRequest(request);
  } catch (error) {
    print('Error handling session termination: $error');
    // Check if headers are already sent
    bool headersSent = false;
    try {
      headersSent = request.response.headers.contentType
          .toString()
          .startsWith('text/event-stream');
    } catch (_) {
      // Ignore errors when checking headers
    }

    if (!headersSent) {
      request.response.statusCode = HttpStatus.internalServerError;
      // Apply CORS headers
      setCorsHeaders(request.response);
      request.response
        ..write('Error processing session termination')
        ..close();
    }
  }
}

// Helper function to collect bytes from an HTTP request
Future<List<int>> collectBytes(HttpRequest request) {
  final completer = Completer<List<int>>();
  final bytes = <int>[];

  request.listen(
    bytes.addAll,
    onDone: () => completer.complete(bytes),
    onError: completer.completeError,
    cancelOnError: true,
  );

  return completer.future;
}