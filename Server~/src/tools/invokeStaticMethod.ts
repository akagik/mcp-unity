import * as z from 'zod';
import { McpUnity } from '../unity/mcpUnity.js';
import { Logger } from '../utils/logger.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { McpUnityError, ErrorType } from '../utils/errors.js';
import { CallToolResult } from '@modelcontextprotocol/sdk/types.js';

// Tool constants
const toolName = 'invoke_static_method';
const toolDescription = 'Invokes any static method with specified parameters';

// Parameter value schema - flexible to accept various types
const parameterValueSchema = z.union([
  z.string(),
  z.number(),
  z.boolean(),
  z.object({
    x: z.number(),
    y: z.number(),
    z: z.number().optional()
  }),
  z.object({
    r: z.number(),
    g: z.number(),
    b: z.number(),
    a: z.number().optional()
  }),
  z.array(z.union([z.string(), z.number(), z.boolean()])),
  z.record(z.any())
]);

// Individual parameter schema
const methodParameterSchema = z.object({
  type: z.string().describe('Parameter type (e.g., string, int, float, bool, Vector3, GameObject)'),
  value: parameterValueSchema.describe('Parameter value')
});

// Main parameters schema
const paramsSchema = z.object({
  typeName: z.string().describe('Full type name including namespace (e.g., UnityEngine.Debug)'),
  methodName: z.string().describe('Method name to invoke'),
  parameters: z.array(methodParameterSchema).optional().describe('Method parameters')
});

export function registerInvokeStaticMethodTool(server: McpServer, mcpUnity: McpUnity, logger: Logger) {
  logger.info(`Registering tool: ${toolName}`);
  
  server.tool(
    toolName,
    toolDescription,
    paramsSchema.shape,
    async (params: any) => {
      try {
        logger.info(`Executing tool: ${toolName}`, params);
        const result = await toolHandler(mcpUnity, params, logger);
        logger.info(`Tool execution successful: ${toolName}`);
        return result;
      } catch (error) {
        logger.error(`Tool execution failed: ${toolName}`, error);
        throw error;
      }
    }
  );
}

async function toolHandler(mcpUnity: McpUnity, params: any, logger: Logger): Promise<CallToolResult> {
  // Validate parameters
  const validation = paramsSchema.safeParse(params);
  if (!validation.success) {
    throw new McpUnityError(
      ErrorType.VALIDATION,
      `Invalid parameters: ${validation.error.message}`
    );
  }

  const { typeName, methodName, parameters } = validation.data;
  
  logger.info(`Invoking static method: ${typeName}.${methodName} with ${parameters?.length || 0} parameters`);

  const response = await mcpUnity.sendRequest({
    method: toolName,
    params: {
      typeName,
      methodName,
      parameters: parameters || []
    }
  });

  if (!response.success) {
    throw new McpUnityError(
      ErrorType.TOOL_EXECUTION,
      response.message || 'Method invocation failed'
    );
  }

  // Build response message
  let message = response.message || `Successfully invoked ${typeName}.${methodName}`;
  
  // Add return value information if present
  if (response.returnValue !== undefined && response.returnValue !== null) {
    message += `\n\nReturn value: ${JSON.stringify(response.returnValue, null, 2)}`;
    if (response.returnType) {
      message += `\nReturn type: ${response.returnType}`;
    }
  }

  return {
    content: [{
      type: response.type || 'text',
      text: message
    }]
  };
}

// Export usage examples
export const invokeStaticMethodExamples = `
## Invoke Static Method Tool Usage Examples

### Example 1: Simple Debug.Log
\`\`\`json
{
  "typeName": "UnityEngine.Debug",
  "methodName": "Log",
  "parameters": [
    {
      "type": "string",
      "value": "Hello from MCP!"
    }
  ]
}
\`\`\`

### Example 2: Create Primitive with Vector3
\`\`\`json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "CreatePrimitive",
  "parameters": [
    {
      "type": "PrimitiveType",
      "value": "Cube"
    }
  ]
}
\`\`\`

### Example 3: PlayerPrefs operations
\`\`\`json
{
  "typeName": "UnityEngine.PlayerPrefs",
  "methodName": "SetInt",
  "parameters": [
    {
      "type": "string",
      "value": "HighScore"
    },
    {
      "type": "int",
      "value": 1000
    }
  ]
}
\`\`\`

### Example 4: EditorUtility dialog
\`\`\`json
{
  "typeName": "UnityEditor.EditorUtility",
  "methodName": "DisplayDialog",
  "parameters": [
    {
      "type": "string",
      "value": "MCP Unity"
    },
    {
      "type": "string",
      "value": "This dialog was created via MCP!"
    },
    {
      "type": "string",
      "value": "OK"
    }
  ]
}
\`\`\`

### Example 5: Working with Vector3
\`\`\`json
{
  "typeName": "YourNamespace.YourClass",
  "methodName": "MoveToPosition",
  "parameters": [
    {
      "type": "Vector3",
      "value": {
        "x": 10.5,
        "y": 0,
        "z": -5.2
      }
    }
  ]
}
\`\`\`

### Supported Parameter Types:
- Primitives: string, int, float, double, bool, long
- Unity types: Vector2, Vector3, Color, GameObject (by name)
- Arrays: string[], int[], float[]
- Enums: Use string value of the enum
- Custom types: Provide full type name
`;