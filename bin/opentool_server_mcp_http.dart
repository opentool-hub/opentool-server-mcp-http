import 'dart:io';
import 'package:args/args.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:mcp_http/mcp_http_tool.dart';
import 'package:opentool_dart/opentool_dart.dart';

String defaultVersion = "1.0.0";
const int PORT = 9641;

void main(List<String> arguments) async {
  final parser = ArgParser();

  parser.addFlag('help', abbr: 'h', negatable: false, help: 'Show help information');

  // --- rename ---
  parser.addCommand('start', ArgParser()
    ..addOption('port', abbr: 'p', help: 'MCP Server Port.', mandatory: true)
    ..addOption('version', abbr: 'v', help: 'OpenTool Server Version. Default: $defaultVersion')
    ..addOption('toolPort', abbr: 't', help: 'OpenTool Server Port. Default: $PORT')
    ..addMultiOption('apiKeys', abbr: 'k', help: 'OpenTool Server APIKEY, allow array, as: --apiKeys KEY_A --apiKeys KEY_B')
    ..addOption('ssl', abbr: 's', help: 'Use HTTPS.')
    ..addOption('host', abbr: 'h', help: 'MCP Server Host. Default: 127.0.0.1')
    ..addOption('accessToken', abbr: 'a', help: 'MCP Server Access Token.')
    ..addOption('refreshToken', abbr: 'r', help: 'MCP Server Refresh Token.'));

  // Handle parsing
  try {

    ArgResults results = parser.parse(arguments);

    if (results['help'] == true || arguments.isEmpty) {
      _printHelp(parser);
      exit(0);
    }

    final command = results.command;

    if (command == null) {
      _printHelp(parser);
      exit(1);
    }

    final cmdName = command.name;

    switch (cmdName) {
      case 'http':
        final toolPort = command['toolPort']??PORT;
        String? version = command['version'];
        if(version != null) defaultVersion = version;
        else version = defaultVersion;
        final mcpSsl = command['ssl'] == null? true : false;
        final mcpHost = command['host']?? "127.0.0.1";
        final mcpPort = command['port']!;
        final mcpAccessToken = command['accessToken']?? null;
        final mcpRefreshToken =  command['refreshToken']?? null;
        final apiKeys = command['apiKeys'] as List<String>?;

        await startMcpHttpTool(
          mcpPort,
          version,
          toolPort: toolPort,
          apiKeys: apiKeys,
          mcpServerSsl: mcpSsl,
          mcpServerHost: mcpHost,
          mcpServerAccessToken: mcpAccessToken,
          mcpServerRefreshToken: mcpRefreshToken
        );
        break;

      default:
        print('Unknown command: $cmdName\n');
        _printHelp(parser);
        exit(1);
    }
  } catch (e) {
    print('❌ Error: $e\n');
    _printHelp(parser);
    exit(64); // standard usage error
  }
}

void _printHelp(ArgParser parser) {
  print('MCP HTTP OpenTool Server ($defaultVersion) - OpenTool Server implement by MCP HTTP.\n');
  print('Usage: mcp_http <command> [options]\n');

  print('Available commands:\n');
  for (final entry in parser.commands.entries) {
    final name = entry.key;
    final usage = entry.value.usage.trimRight();
    print('Command: $name');
    print(usage.split('\n').map((line) => '  $line').join('\n'));
    print('');
  }

  print('Global options:\n');
  print(parser.usage);
}

Future<void> startMcpHttpTool(
    int mcpServerPort,
    String version,
    { int toolPort = PORT,
      List<String>? apiKeys,
      bool mcpServerSsl = false,
      String mcpServerHost = "127.0.0.1",
      String? mcpServerAccessToken,
      String? mcpServerRefreshToken
    }) async {
  String protocol = mcpServerSsl ? "https":"http";
  OAuthTokens? oAuthTokens;
  if(mcpServerAccessToken != null) oAuthTokens = OAuthTokens(accessToken: mcpServerAccessToken, refreshToken: mcpServerRefreshToken);
  McpHttp mcpHttp = McpHttp(url: "$protocol://$mcpServerHost:$mcpServerPort/mcp", oAuthTokens: oAuthTokens);
  McpHttpTool mcpHttpTool = McpHttpTool(mcpHttp);
  mcpHttpTool.init();
  Server server = OpenToolServer(mcpHttpTool, version, port: PORT, apiKeys: apiKeys);
  await server.start();
}

class AuthProvider extends mcp.OAuthClientProvider {
  OAuthTokens oAuthTokens;

  AuthProvider(this.oAuthTokens);

  @override
  Future<void> redirectToAuthorization() async {
    /// Add your logic to redirect the user to the OAuth authorization page.
  }

  @override
  Future<mcp.OAuthTokens?> tokens() async {
    return mcp.OAuthTokens(
      accessToken: oAuthTokens.accessToken,
      refreshToken: oAuthTokens.refreshToken,
    );
  }
}