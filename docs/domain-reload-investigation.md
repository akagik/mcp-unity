# Unity ドメインリロードと WebSocketServer 永続化の調査結果

## 1. 現在StopServerが必要な理由の分析

### WebSocketServerインスタンスの状態
- **ドメインリロード後の有効性**: WebSocketServerインスタンスは、ドメインリロード後は**無効**になります
- 理由:
  - Unityのドメインリロードは、すべてのマネージドコード（C#）をアンロードし、再ロードします
  - 静的変数は初期状態にリセットされます（`[InitializeOnLoad]`で再初期化される）
  - WebSocketServerが内部で管理するスレッドやリソースへの参照が失われます

### WebSocketSharpのスレッドとリソース
- WebSocketSharpは内部で以下のリソースを管理します:
  - **リスナースレッド**: TCP接続を受け入れるためのスレッド
  - **ワーカースレッド**: 各WebSocket接続を処理するスレッド
  - **ソケットハンドル**: OSレベルのソケットリソース
- ドメインリロード時:
  - マネージドスレッドへの参照は失われます
  - しかし、**ネイティブスレッドは生き残る可能性があります**
  - ソケットハンドルがOSレベルで残る可能性があります

### ポートバインディングの状態
- `ReuseAddress = true`の設定により、同じポートへの再バインドは可能
- しかし、前のソケットが適切にクローズされていない場合:
  - リソースリーク
  - 予期しない動作
  - パフォーマンスの低下

## 2. Unityの静的変数保持オプション

### [InitializeOnLoadMethod]と[InitializeOnLoad]の違い
- **[InitializeOnLoad]**: クラスの静的コンストラクタが呼ばれる
  - ドメインリロード後に自動的に実行される
  - 現在の実装で使用されている
- **[InitializeOnLoadMethod]**: 指定されたメソッドが呼ばれる
  - より細かい制御が可能

### DontDestroyOnLoadの代替手段
- `DontDestroyOnLoad`はランタイム（PlayMode）専用
- エディタでの代替手段:
  - **ScriptableObject**: アセットとして保存可能だが、ドメインリロードでリセット
  - **EditorPrefs/SessionState**: プリミティブ値のみ保存可能
  - **ネイティブプラグイン**: C++レベルでリソースを管理（複雑）

### EditorApplicationのdomainReloading設定
```csharp
EditorSettings.enterPlayModeOptionsEnabled = true;
EditorSettings.enterPlayModeOptions = EnterPlayModeOptions.DisableDomainReload;
```
- ドメインリロードを無効化できるが:
  - 開発体験が低下
  - 静的変数の状態が予期せず保持される
  - 推奨されない

### [SerializeField]やScriptableObjectの活用可能性
- シリアライズ可能な情報のみ保存可能
- WebSocketServerのようなリソースハンドルは保存不可

## 3. WebSocketServerの永続化可能性

### 管理されるリソースの詳細
1. **TCPリスナー**: OSレベルのソケット
2. **接続プール**: アクティブなWebSocket接続
3. **スレッドプール**: 非同期処理用
4. **イベントハンドラー**: C#のデリゲート

### スレッドの生存期間
- **マネージドスレッド**: ドメインリロードで終了
- **ネイティブスレッド**: 生き残る可能性があるが、参照が失われる
- **結果**: メモリリークやデッドスレッドの原因

### ソケットハンドルの扱い
- ドメインリロード時にGCによる自動クリーンアップは保証されない
- 明示的なClose()が必要

## 4. 既存の問題確認

### OnBeforeAssemblyReloadでStopServerする理由
1. **リソースリークの防止**: ソケットやスレッドの適切な解放
2. **ポート競合の回避**: 次回起動時の問題を防ぐ
3. **クリーンな状態の保証**: 予期しない動作の防止

### 停止しない場合の問題
1. **ポートバインディングエラー**: "Address already in use"
2. **メモリリーク**: 解放されないリソース
3. **ゾンビスレッド**: 制御不能なスレッド
4. **接続の混乱**: 古い接続と新しい接続の混在

### ReuseAddress=trueの設定との関係
- `ReuseAddress`は同じポートの再利用を許可
- しかし、前のソケットが適切にクローズされていることが前提
- 不適切な使用はデータの混乱を招く

## 5. 代替アプローチの検討

### A. プロセス分離アプローチ
```csharp
// 別プロセスでWebSocketServerを実行
Process.Start("WebSocketServer.exe", $"--port {port}");
```
- メリット: ドメインリロードの影響を受けない
- デメリット: プロセス間通信の複雑さ

### B. ネイティブプラグインアプローチ
```cpp
// C++でWebSocketServerを実装
extern "C" {
    void* CreateWebSocketServer(int port);
    void DestroyWebSocketServer(void* server);
}
```
- メリット: 完全な制御
- デメリット: 実装の複雑さ、プラットフォーム依存

### C. 接続状態の保存と復元
```csharp
[Serializable]
public class ConnectionState {
    public string clientId;
    public string clientName;
    // シリアライズ可能な情報のみ
}

// ドメインリロード前に保存
EditorPrefs.SetString("ConnectionStates", JsonUtility.ToJson(states));

// ドメインリロード後に復元
var states = JsonUtility.FromJson<ConnectionState[]>(
    EditorPrefs.GetString("ConnectionStates")
);
```
- メリット: 部分的な状態復元が可能
- デメリット: 完全な接続復元は不可能

### D. 現在のアプローチの最適化
現在の実装（停止→再起動）が最も安全で推奨される理由:
1. **確実なリソース管理**
2. **予測可能な動作**
3. **デバッグの容易さ**
4. **メンテナンスの簡単さ**

## 結論

WebSocketServerを停止せずにドメインリロードを乗り越える実装は**技術的に不可能**です。

理由:
1. Unityのドメインリロードはすべてのマネージドコードをアンロードする
2. WebSocketServerが管理するリソース（スレッド、ソケット）への参照が失われる
3. ネイティブリソースの適切な管理が保証されない

**推奨事項**:
1. 現在の実装（OnBeforeAssemblyReloadでの停止）を維持する
2. クライアント側（Node.js）に自動再接続機能を実装する
3. 接続状態の情報をシリアライズ可能な形で保存し、再接続時に復元する

この方法により、ユーザー体験を向上させながら、安定性と信頼性を確保できます。