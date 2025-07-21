# MCP Unity カスタムAPI作成ガイド

このガイドでは、MCP Unityプロジェクトに独自の引数付きAPIを追加する手順を説明します。

## 概要

MCP Unityでは、2種類のカスタムAPIを作成できます：
- **ツール（Tool）**: Unity内で操作を実行するAPI（例：GameObjectの作成、コンポーネントの追加）
- **リソース（Resource）**: Unity内のデータを取得するAPI（例：シーンの情報、アセットの一覧）

## カスタムツールの作成手順

### 1. Unity側（C#）の実装

#### ステップ1: ツールクラスを作成

`Editor/Tools/`ディレクトリに新しいC#ファイルを作成します。

```csharp
// Editor/Tools/MyCustomTool.cs
using System;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json.Linq;
using McpUnity.Unity;
using McpUnity.Utils;

namespace McpUnity.Tools
{
    public class MyCustomTool : McpToolBase
    {
        public MyCustomTool()
        {
            Name = "my_custom_tool";
            Description = "カスタムツールの説明";
            IsAsync = false; // 非同期処理が必要な場合は true
        }
        
        public override JObject Execute(JObject parameters)
        {
            // パラメータの取得
            string objectName = parameters["objectName"]?.ToObject<string>();
            Vector3? position = null;
            
            if (parameters["position"] != null)
            {
                position = new Vector3(
                    parameters["position"]["x"]?.ToObject<float>() ?? 0,
                    parameters["position"]["y"]?.ToObject<float>() ?? 0,
                    parameters["position"]["z"]?.ToObject<float>() ?? 0
                );
            }
            
            // バリデーション
            if (string.IsNullOrEmpty(objectName))
            {
                return McpUnitySocketHandler.CreateErrorResponse(
                    "Required parameter 'objectName' not provided", 
                    "validation_error"
                );
            }
            
            // 処理の実装
            try
            {
                // Unity APIを使用した処理
                GameObject newObject = new GameObject(objectName);
                if (position.HasValue)
                {
                    newObject.transform.position = position.Value;
                }
                
                // Undo対応
                Undo.RegisterCreatedObjectUndo(newObject, "Create GameObject");
                
                return new JObject
                {
                    ["success"] = true,
                    ["type"] = "text",
                    ["message"] = $"GameObject '{objectName}' created successfully",
                    ["instanceId"] = newObject.GetInstanceID()
                };
            }
            catch (Exception ex)
            {
                return McpUnitySocketHandler.CreateErrorResponse(
                    $"Error creating GameObject: {ex.Message}", 
                    "execution_error"
                );
            }
        }
    }
}
```

#### ステップ2: ツールを登録

`Editor/UnityBridge/McpUnityServer.cs`の`RegisterTools()`メソッドに追加：

```csharp
private void RegisterTools()
{
    // 既存のツール登録...
    
    // カスタムツールの登録
    MyCustomTool myCustomTool = new MyCustomTool();
    _tools.Add(myCustomTool.Name, myCustomTool);
}
```

### 2. Node.js側（TypeScript）の実装

#### ステップ1: ツールハンドラーを作成

`Server~/src/tools/`ディレクトリに新しいTypeScriptファイルを作成します。

```typescript
// Server~/src/tools/myCustomTool.ts
import * as z from 'zod';
import { McpUnity } from '../unity/mcpUnity.js';
import { Logger } from '../utils/logger.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { McpUnityError, ErrorType } from '../utils/errors.js';
import { CallToolResult } from '@modelcontextprotocol/sdk/types.js';

// ツール定数
const toolName = 'my_custom_tool';
const toolDescription = 'Create a new GameObject with optional position';

// パラメータスキーマ（Zodを使用）
const paramsSchema = z.object({
  objectName: z.string().describe('Name of the GameObject to create'),
  position: z.object({
    x: z.number().describe('X coordinate'),
    y: z.number().describe('Y coordinate'),
    z: z.number().describe('Z coordinate')
  }).optional().describe('Optional position for the GameObject')
});

export function registerMyCustomTool(server: McpServer, mcpUnity: McpUnity, logger: Logger) {
    logger.info(`Registering tool: ${toolName}`);
    
    server.tool(
      toolName,
      toolDescription,
      paramsSchema.shape,
      async (params: any) => {
        try {
          logger.info(`Executing tool: ${toolName}`, params);
          const result = await toolHandler(mcpUnity, params);
          logger.info(`Tool execution successful: ${toolName}`);
          return result;
        } catch (error) {
          logger.error(`Tool execution failed: ${toolName}`, error);
          throw error;
        }
      }
    );
}

async function toolHandler(mcpUnity: McpUnity, params: any): Promise<CallToolResult> {
    // パラメータバリデーション
    const validation = paramsSchema.safeParse(params);
    if (!validation.success) {
        throw new McpUnityError(
            ErrorType.VALIDATION,
            `Invalid parameters: ${validation.error.message}`
        );
    }

    const response = await mcpUnity.sendRequest({
        method: toolName,
        params: validation.data
    });

    if (!response.success) {
        throw new McpUnityError(
            ErrorType.TOOL_EXECUTION,
            response.message || 'Tool execution failed'
        );
    }

    return {
        content: [{
            type: response.type || 'text',
            text: response.message || 'Success'
        }]
    };
}
```

#### ステップ2: ツールを登録

`Server~/src/index.ts`に追加：

```typescript
// インポート
import { registerMyCustomTool } from './tools/myCustomTool.js';

// ツールの登録（他のツール登録と同じ場所に追加）
registerMyCustomTool(server, mcpUnity, toolLogger);
```

## カスタムリソースの作成手順

### 1. Unity側（C#）の実装

```csharp
// Editor/Resources/GetCustomDataResource.cs
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json.Linq;

namespace McpUnity.Resources
{
    public class GetCustomDataResource : McpResourceBase
    {
        public GetCustomDataResource()
        {
            Name = "get_custom_data";
            Description = "Get custom data from Unity";
            Uri = "unity://custom/{dataType}";
            IsAsync = false;
        }
        
        public override JObject Fetch(JObject parameters)
        {
            string dataType = parameters["dataType"]?.ToObject<string>();
            
            if (string.IsNullOrEmpty(dataType))
            {
                return new JObject
                {
                    ["success"] = false,
                    ["message"] = "Required parameter 'dataType' not provided"
                };
            }
            
            try
            {
                JObject data = new JObject();
                
                switch (dataType.ToLower())
                {
                    case "project":
                        data["projectName"] = PlayerSettings.productName;
                        data["companyName"] = PlayerSettings.companyName;
                        data["unityVersion"] = Application.unityVersion;
                        break;
                        
                    case "scene":
                        var activeScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
                        data["sceneName"] = activeScene.name;
                        data["scenePath"] = activeScene.path;
                        data["objectCount"] = activeScene.rootCount;
                        break;
                        
                    default:
                        return new JObject
                        {
                            ["success"] = false,
                            ["message"] = $"Unknown data type: {dataType}"
                        };
                }
                
                return new JObject
                {
                    ["success"] = true,
                    ["message"] = "Data retrieved successfully",
                    ["data"] = data
                };
            }
            catch (Exception ex)
            {
                return new JObject
                {
                    ["success"] = false,
                    ["message"] = $"Error: {ex.Message}"
                };
            }
        }
    }
}
```

### 2. Node.js側（TypeScript）の実装

```typescript
// Server~/src/resources/getCustomData.ts
import * as z from 'zod';
import { McpUnity } from '../unity/mcpUnity.js';
import { Logger } from '../utils/logger.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { McpUnityError, ErrorType } from '../utils/errors.js';
import { GetResourceResult } from '@modelcontextprotocol/sdk/types.js';

const resourceName = 'get_custom_data';
const resourceDescription = 'Get custom data from Unity';

const paramsSchema = z.object({
  dataType: z.enum(['project', 'scene']).describe('Type of data to retrieve')
});

export function registerGetCustomDataResource(server: McpServer, mcpUnity: McpUnity, logger: Logger) {
    logger.info(`Registering resource: ${resourceName}`);
    
    server.resource(
      `unity://custom/{dataType}`,
      resourceName,
      resourceDescription,
      async (uri: string) => {
        const match = uri.match(/^unity:\/\/custom\/(.+)$/);
        if (!match) {
          throw new McpUnityError(ErrorType.VALIDATION, 'Invalid URI format');
        }
        
        const dataType = match[1];
        return resourceHandler(mcpUnity, { dataType });
      }
    );
}

async function resourceHandler(mcpUnity: McpUnity, params: any): Promise<GetResourceResult> {
    const validation = paramsSchema.safeParse(params);
    if (!validation.success) {
        throw new McpUnityError(
            ErrorType.VALIDATION,
            `Invalid parameters: ${validation.error.message}`
        );
    }

    const response = await mcpUnity.sendRequest({
        method: resourceName,
        params: validation.data
    });

    if (!response.success) {
        throw new McpUnityError(
            ErrorType.RESOURCE_FETCH,
            response.message || 'Resource fetch failed'
        );
    }

    return {
        contents: [{
            uri: `unity://custom/${params.dataType}`,
            mimeType: 'application/json',
            text: JSON.stringify(response.data, null, 2)
        }]
    };
}
```

## パラメータ型リファレンス

### Zodスキーマの例

```typescript
const advancedParamsSchema = z.object({
  // 基本型
  stringParam: z.string(),
  numberParam: z.number(),
  booleanParam: z.boolean(),
  
  // オプショナル
  optionalString: z.string().optional(),
  
  // デフォルト値
  withDefault: z.string().default('default'),
  
  // 制約付き
  minMaxNumber: z.number().min(0).max(100),
  enumParam: z.enum(['option1', 'option2', 'option3']),
  
  // 配列
  stringArray: z.array(z.string()),
  
  // オブジェクト
  nestedObject: z.object({
    x: z.number(),
    y: z.number(),
    z: z.number()
  }),
  
  // Union型
  mixedType: z.union([z.string(), z.number()])
});
```

## エラーハンドリング

### Unity側のエラータイプ

```csharp
// バリデーションエラー
return McpUnitySocketHandler.CreateErrorResponse(
    "Invalid parameter value", 
    "validation_error"
);

// 実行エラー
return McpUnitySocketHandler.CreateErrorResponse(
    "Failed to execute operation", 
    "execution_error"
);

// リソースが見つからない
return McpUnitySocketHandler.CreateErrorResponse(
    "Resource not found", 
    "not_found_error"
);
```

### Node.js側のエラータイプ

```typescript
export enum ErrorType {
    VALIDATION = 'validation_error',
    CONNECTION = 'connection_error',
    TIMEOUT = 'timeout_error',
    TOOL_EXECUTION = 'tool_execution_error',
    RESOURCE_FETCH = 'resource_fetch_error',
    UNKNOWN = 'unknown_error'
}
```

## デバッグとテスト

### 1. ビルドとテスト

```bash
cd Server~
npm run build
npm run inspector
```

### 2. ログの確認

- Unity側: Consoleウィンドウで`[MCP Unity]`プレフィックスのログを確認
- Node.js側: ターミナルでサーバーログを確認

### 3. MCP Inspectorでテスト

1. `npm run inspector`を実行
2. ブラウザで表示されるUIから新しいツール/リソースをテスト
3. パラメータを入力して実行結果を確認

## ベストプラクティス

1. **エラーハンドリング**: 常に適切なエラーレスポンスを返す
2. **Undo対応**: Unity操作では`Undo.RecordObject()`を使用
3. **非同期処理**: 長時間かかる処理は`IsAsync = true`を設定
4. **ログ出力**: デバッグのために適切なログを出力
5. **バリデーション**: パラメータは必ず検証してから使用
6. **型安全性**: TypeScriptではZodスキーマで型を定義

これらの手順に従うことで、MCP Unityプロジェクトに独自の引数付きAPIを追加できます。