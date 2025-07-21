# MCP Unity プロジェクト概要

## プロジェクトの目的

MCP Unity は、AIアシスタント（Claude、Cursor、Windsurf など）が Unity Editor を操作できるようにするブリッジシステムです。Model Context Protocol (MCP) を使用して、自然言語でUnityプロジェクトを操作できます。

## アーキテクチャ概要

```
[AIクライアント] <--MCP(STDIO)--> [Node.jsサーバー] <--WebSocket--> [Unity Editor]
```

## 重要ファイルの説明

### Unity側（C#）- Editor/

#### コアシステム
- **McpUnityServer.cs** - WebSocketサーバーのメイン管理クラス
  - サーバーの起動・停止
  - ツール/リソースの登録
  - クライアント接続管理

- **McpUnitySocketHandler.cs** - WebSocket通信ハンドラー
  - メッセージの送受信処理
  - JSON-RPC 2.0プロトコル処理
  - Unity メインスレッドでの実行調整

- **McpToolBase.cs / McpResourceBase.cs** - 拡張用基底クラス
  - ツール：Unity操作を実行（GameObject作成、更新など）
  - リソース：Unity情報を取得（シーン階層、ログなど）

#### 主要ツール (Editor/Tools/)
- **UpdateGameObjectTool.cs** - GameObjectのプロパティ更新
- **SelectGameObjectTool.cs** - GameObject選択
- **UpdateComponentTool.cs** - コンポーネント追加・更新
- **AddAssetToSceneTool.cs** - アセットをシーンに配置
- **MenuItemTool.cs** - Unityメニュー項目実行
- **AddPackageTool.cs** - パッケージインストール
- **RunTestsTool.cs** - テスト実行
- **SendConsoleLogTool.cs** - コンソールログ送信

#### 主要リソース (Editor/Resources/)
- **GetGameObjectResource.cs** - GameObject情報取得
- **GetScenesHierarchyResource.cs** - シーン階層取得
- **GetMenuItemsResource.cs** - メニュー項目一覧取得
- **GetConsoleLogsResource.cs** - コンソールログ取得
- **GetPackagesResource.cs** - パッケージ情報取得
- **GetAssetsResource.cs** - アセット情報取得
- **GetTestsResource.cs** - テスト情報取得

### Node.js側（TypeScript）- Server~/

#### コアシステム
- **index.ts** - エントリポイント
  - MCPサーバー初期化
  - ツール/リソース登録

- **mcpUnity.ts** - Unity WebSocket クライアント
  - Unity接続管理
  - リクエスト/レスポンス処理
  - 再接続ロジック

#### ツール/リソース実装
- **src/tools/** - 各ツールのTypeScript実装
- **src/resources/** - 各リソースのTypeScript実装
- **src/prompts/** - GameObject操作用AIプロンプト

### 設定ファイル

#### Unity側
- **package.json** - Unityパッケージ定義
  - 依存関係（Newtonsoft.Json、EditorCoroutines、TestFramework）
- **McpUnity.Editor.asmdef** - アセンブリ定義

#### Node.js側
- **Server~/package.json** - Node.js依存関係
- **Server~/tsconfig.json** - TypeScript設定
- **glama.json** - MCPサーバーメタデータ

#### プロジェクト設定
- **ProjectSettings/McpUnitySettings.json** - Unity MCP設定
  - ポート番号（デフォルト: 8090）
  - タイムアウト設定
  - リモート接続許可

## 主な機能

1. **GameObject操作** - 作成、更新、選択、階層構造の管理
2. **コンポーネント管理** - 追加、更新、プロパティ変更
3. **アセット管理** - アセット検索、シーンへの配置
4. **パッケージ管理** - Unity Package Managerの操作
5. **テスト実行** - Unity Test Runnerの操作
6. **ログ管理** - コンソールログの取得・送信
7. **メニュー実行** - Unity Editorメニューの実行

## 動作フロー

1. AIクライアントがMCPリクエストを送信
2. Node.jsサーバーがリクエストを受信・解析
3. WebSocket経由でUnity Editorに転送
4. Unity側で操作を実行（メインスレッド）
5. 結果をNode.js経由でAIクライアントに返信

## 拡張方法

新しい機能を追加する場合：
1. Unity側：`McpToolBase`または`McpResourceBase`を継承
2. Node.js側：対応するTypeScriptファイルを作成
3. `index.ts`に登録を追加

このアーキテクチャにより、AIアシスタントとUnity Editorの自然な対話が実現されています。