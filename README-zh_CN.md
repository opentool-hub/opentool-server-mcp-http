# MCP HTTP mode for OpenTool

[English](README.md) | 中文

OpenTool的MCP HTTP客户端实现，运行opentool的请求来执行MCP HTTP的操作

## 构建

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

## 示例

1. 拉起样例OpenTool Server， 
   - 方式1：运行 `example/server.dart`
   - 方式2：运行命令行 `build/mcp_http start --port 3000`
2. 运行 `example/client.dart`