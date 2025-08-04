import '../bin/opentool_server_mcp_http.dart';
import 'mock_mcp_http_server.dart';

/// CLI Mode
/// build/mcp_http start -p 3000 -v 1.0.0 -k "6621c8a3-2110-4e6a-9d62-70ccd467e789" -k "bb31b6a6-1fda-4214-8cd6-b1403842070c"

/// CODE Mode
Future<void> main(List<String> args) async {
  bool ssl = false;
  String mcpServerHost = "127.0.0.1";
  int mcpServerPort = 3000;

  await startMcpHttpServer(port: mcpServerPort, onPostStart: () async {
    startMcpHttpTool(
      mcpServerPort,
      "1.0.0",
      toolPort: PORT,
      apiKeys: ["6621c8a3-2110-4e6a-9d62-70ccd467e789", "bb31b6a6-1fda-4214-8cd6-b1403842070c"],
      mcpServerSsl: ssl,
      mcpServerHost: mcpServerHost,
      mcpServerAccessToken: null,
      mcpServerRefreshToken: null
    );
  });
}