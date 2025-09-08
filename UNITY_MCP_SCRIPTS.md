# Unity MCP Scripts - 使用ガイド

Unity EditorをシェルスクリプトからMCPプロトコル経由で操作するための軽量ツール集です。
WebSocketクライアントツール（websocat等）は不要で、Node.jsのみで動作します。

## 📦 提供スクリプト

### 1. execute_unity_menu.sh
Unity EditorのMenuItemを実行するスクリプト

### 2. get_console_logs.sh  
Unityのコンソールログを取得するスクリプト

## 🚀 クイックスタート

```bash
# スクリプトに実行権限を付与（初回のみ）
chmod +x execute_unity_menu.sh get_console_logs.sh

# GameObject を作成
./execute_unity_menu.sh "GameObject/Create Empty"

# コンソールログを確認
./get_console_logs.sh 10
```

## 📝 execute_unity_menu.sh

### 概要
Unity EditorのMenuItemをコマンドラインから実行します。
プロジェクトのビルド、スクリプトのリロード、GameObjectの作成など、Unity Editorの全てのメニュー操作が可能です。

### 使用方法
```bash
./execute_unity_menu.sh <menu_path> [server_path]
```

### パラメータ
- `menu_path` (必須): 実行するMenuItemのパス
- `server_path` (任意): MCPサーバー(index.js)のパス

### 実行例

#### 基本的な使用
```bash
# GameObject を作成
./execute_unity_menu.sh "GameObject/Create Empty"

# コンソールウィンドウを開く
./execute_unity_menu.sh "Window/General/Console"

# プロジェクトを保存
./execute_unity_menu.sh "File/Save Project"

# スクリプトを強制リロード
./execute_unity_menu.sh "Tools/ForceScriptReload"
```

#### サーバーパスを指定
```bash
# PackageCacheから実行
./execute_unity_menu.sh "File/Save" ./Library/PackageCache/com.gamelovers.mcp-unity@*/Server~/build/index.js

# 絶対パスで指定
./execute_unity_menu.sh "Edit/Undo" /Users/kohei/Projects/modules/unity-mcp-server/Packages/McpUnity/Server~/build/index.js
```

#### 環境変数を使用
```bash
# 環境変数でサーバーパスを設定
export MCP_SERVER_PATH="./Server~/build/index.js"

# 以降はパス指定不要
./execute_unity_menu.sh "GameObject/Create Empty"
./execute_unity_menu.sh "Assets/Reimport All"
```

### よく使うMenuItemの例
| コマンド | 説明 |
|---------|------|
| `"File/Save Project"` | プロジェクトを保存 |
| `"File/Save Scene"` | シーンを保存 |
| `"GameObject/Create Empty"` | 空のGameObjectを作成 |
| `"GameObject/3D Object/Cube"` | Cubeを作成 |
| `"Assets/Reimport All"` | 全アセットを再インポート |
| `"Tools/ForceScriptReload"` | スクリプトを強制リロード |
| `"Window/General/Console"` | コンソールウィンドウを開く |
| `"Window/General/Project"` | プロジェクトウィンドウを開く |
| `"Edit/Play"` | プレイモードを開始 |
| `"Edit/Pause"` | プレイモードを一時停止 |

## 📊 get_console_logs.sh

### 概要
Unity Editorのコンソールログ（通常ログ、警告、エラー）を取得して表示します。
デバッグやCI/CDでのエラー確認に便利です。

### 使用方法
```bash
./get_console_logs.sh [server_path] [log_type] [limit]
```

### パラメータ
- `server_path` (任意): MCPサーバーのパス
- `log_type` (任意): `info`, `warning`, `error` のいずれか
- `limit` (任意): 取得するログの件数（デフォルト: 10）

### 実行例

#### 基本的な使用
```bash
# 最新10件のログを取得
./get_console_logs.sh

# 最新20件のログを取得
./get_console_logs.sh 20

# エラーログのみ取得
./get_console_logs.sh error

# 警告ログを5件取得
./get_console_logs.sh warning 5
```

#### サーバーパスを指定
```bash
# サーバーパスを指定して10件取得
./get_console_logs.sh ./Server~/build/index.js 10

# サーバーパスを指定してエラーログのみ
./get_console_logs.sh ./Server~/build/index.js error
```

### 出力例
```
Unity Console Logs
Server: ./Server~/build/index.js
Limit: 5
==================

📝 [2025-09-09 02:34:31.247] RequestScriptReload 実行済み
📝 [2025-09-09 02:35:12.893] GameObject Created: New GameObject
⚠️ [2025-09-09 02:35:45.123] Shader warning in 'Custom/TestShader'
❌ [2025-09-09 02:36:01.456] NullReferenceException: Object reference not set

✅ 完了
```

### ログタイプと表示
- **通常ログ (info)**: 📝 シアン色で表示
- **警告 (warning)**: ⚠️ 黄色で表示  
- **エラー (error)**: ❌ 赤色で表示

## ⚙️ 設定

### 環境変数
```bash
# .bashrc または .zshrc に追加
export MCP_SERVER_PATH="/path/to/Server~/build/index.js"
```

### サーバーパスの自動検出
スクリプトは以下の順序でMCPサーバーを探します：
1. コマンドライン引数で指定されたパス
2. `MCP_SERVER_PATH` 環境変数
3. `./Server~/build/index.js`
4. `./Packages/McpUnity/Server~/build/index.js`
5. `./Library/PackageCache/com.gamelovers.mcp-unity@*/Server~/build/index.js`

## 🔧 トラブルシューティング

### MCPサーバーが見つからない
```bash
エラー: MCPサーバーが見つかりません
```
**解決方法:**
1. Unity Editorが起動していることを確認
2. MCP Unity ServerのWebSocketが起動していることを確認（デフォルトポート: 8090）
3. サーバーパスを明示的に指定:
   ```bash
   ./execute_unity_menu.sh "File/Save" /path/to/Server~/build/index.js
   ```

### レスポンスなし
```bash
レスポンスなし
```
**解決方法:**
1. Unity Editorがフリーズしていないか確認
2. Unity ConsoleでMCPサーバーのログを確認
3. Node.jsがインストールされているか確認: `node --version`

### 実行成功するが効果がない
**確認事項:**
1. Unity Editorがフォーカスされているか
2. プレイモード中でないか（一部のMenuItemは編集モードでのみ動作）
3. `get_console_logs.sh`でログを確認

## 💡 活用例

### CI/CDでの使用
```bash
#!/bin/bash
# build.sh - Unityプロジェクトのビルドスクリプト

# エラーログをクリア
./execute_unity_menu.sh "Edit/Clear All PlayerPrefs"

# プロジェクトを保存
./execute_unity_menu.sh "File/Save Project"

# ビルド実行
./execute_unity_menu.sh "File/Build Settings"

# エラーチェック
if ./get_console_logs.sh error | grep -q "Build failed"; then
    echo "ビルド失敗"
    exit 1
fi
```

### デバッグワークフロー
```bash
# 1. スクリプトをリロード
./execute_unity_menu.sh "Tools/ForceScriptReload"

# 2. コンパイルエラーを確認
./get_console_logs.sh error

# 3. 警告を確認
./get_console_logs.sh warning 20

# 4. テスト実行
./execute_unity_menu.sh "Window/General/Test Runner"
```

### バッチ処理
```bash
#!/bin/bash
# batch_create.sh - 複数のGameObjectを作成

for i in {1..5}; do
    echo "Creating GameObject $i"
    ./execute_unity_menu.sh "GameObject/Create Empty"
    sleep 1
done

# 結果を確認
./get_console_logs.sh 10
```

## 📋 動作要件

- **Unity Editor** 2020.3以降
- **Node.js** 14.0以降
- **MCP Unity Server** がインストール済み
- **macOS/Linux** (Windowsの場合はWSL推奨)

## 🚨 注意事項

- Unity Editorが起動している必要があります
- MCP Unity ServerのWebSocketサーバーが起動している必要があります（通常は自動起動）
- プレイモード中は一部のMenuItemが実行できません
- 重い処理（Reimport All等）は時間がかかることがあります

## 📄 ライセンス

これらのスクリプトはMCP Unityプロジェクトの一部として提供されています。

---

## クイックリファレンス

```bash
# よく使うコマンド
./execute_unity_menu.sh "GameObject/Create Empty"  # GameObject作成
./execute_unity_menu.sh "File/Save Project"        # 保存
./execute_unity_menu.sh "Tools/ForceScriptReload"  # リロード
./get_console_logs.sh 20                           # ログ20件
./get_console_logs.sh error                        # エラーのみ
```