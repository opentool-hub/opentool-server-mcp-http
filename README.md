# MCP HTTP mode for OpenTool

English | [中文](README-zh_CN.md)

An OpenTool-compatible MCP HTTP client implementation that handles OpenTool requests to perform MCP HTTP operations.

## Build

### Windows

```bash
dart pub get
dart compile exe bin/opentool_server_mcp_http.dart -o build/mcp_http.exe
```

### macOS / Linux

```bash
dart pub get
dart compile exe bin/opentool_server_mcp_http.dart -o build/mcp_http
```

## Example

1. Launch a sample OpenTool Server:

    * Option 1: Run `example/server.dart`
    * Option 2: Run the CLI command `build/mcp_http start --port 3000`
2. Run `example/client.dart`