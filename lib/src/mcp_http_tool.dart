import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:opentool_dart/opentool_dart.dart';
import 'model.dart';

class McpHttpTool extends Tool {
  late mcp.Client client;
  late mcp.StreamableHttpClientTransport transport;
  late List<FunctionModel> functionModelList;
  String? sessionId;

  McpHttpTool(McpHttp mcpHttp, {mcp.OAuthClientProvider? authProvider, void Function()? onTransportClose}) {
    Uri url = Uri.parse(mcpHttp.url);
    mcp.StreamableHttpClientTransportOptions httpOptions = mcp.StreamableHttpClientTransportOptions(
      authProvider: authProvider,
      sessionId: sessionId
    );

    transport = mcp.StreamableHttpClientTransport(url, opts: httpOptions);

    mcp.Implementation clientInfo = mcp.Implementation(name: 'McpHttpTool', version: '1.0.0');

    client = mcp.Client(clientInfo);

    transport.onerror = (error) {
      throw error;
    };

    transport.onclose = () {
      if(onTransportClose != null) onTransportClose();
    };
  }

  Future<void> init() async {
    await client.connect(transport);
    this.sessionId = transport.sessionId;
  }

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic>? arguments) async {
    mcp.CallToolResult callToolResult = await client.callTool(mcp.CallToolRequestParams(name: name, arguments: arguments));
    return callToolResult.toJson();
  }

  @override
  Future<OpenTool?> load() async {
    mcp.ListToolsResult listToolsResult = await client.listTools();
    functionModelList = _convertToFunctionModelList(listToolsResult);
    return OpenTool(
        opentool: "1.0.0",
        info: Info(title: "MCP STDIO Tool", version: "1.0.0", description: "MCP STDIO for OpenTool."),
        functions: functionModelList
    );
  }

  List<FunctionModel> _convertToFunctionModelList(mcp.ListToolsResult listToolsResult) {
    return listToolsResult.tools.map((mcp.Tool tool){
      return FunctionModel(
          name: tool.name,
          description: tool.description??"",
          parameters: _convertToolInputSchemaToParameters(tool.inputSchema)
      );
    }).toList();
  }

  List<Parameter> _convertToolInputSchemaToParameters(mcp.ToolInputSchema schema, {List<String>? required}) {
    if (schema.properties == null) {
      return [];
    }

    return schema.properties!.entries.map((entry) {
      final name = entry.key;
      final value = entry.value as Map<String, dynamic>;
      final isRequired = required?.contains(name) ?? false;

      return Parameter(
        name: name,
        description: value['description'],
        required: isRequired,
        schema: parseSchema(value),
      );
    }).toList();
  }

  Schema parseSchema(Map<String, dynamic> schemaMap) {
    String type = schemaMap['type'] as String;
    String? description = schemaMap['description'] as String?;
    List<String>? enumValues = schemaMap.containsKey('enum') ? List<String>.from(schemaMap['enum']) : null;

    Schema? items;
    if (type == 'array' && schemaMap.containsKey('items')) {
      items = parseSchema(schemaMap['items'] as Map<String, dynamic>);
    }

    Map<String, Schema>? properties;
    List<String>? required;
    if (type == 'object') {
      properties = schemaMap.containsKey('properties') ? (schemaMap['properties'] as Map<String, dynamic>).map((key, value) => MapEntry(key, parseSchema(value as Map<String, dynamic>))) : null;
      required = schemaMap.containsKey('required') ? List<String>.from(schemaMap['required']) : null;
    }

    return Schema(type: type, description: description, properties: properties, items: items, enum_: enumValues, required: required,);
  }

}