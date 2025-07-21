# Unity MCPサーバー リコンパイル後の接続切断問題 調査レポート

## 問題の概要

Unity MCPサーバーは、Unityエディタでリコンパイルが発生すると、Claude Codeとの接続が切断され、Unityエディタを再度アクティブにするまで再接続されない。この問題により、連続的なコンパイル・エラー修正のワークフローが妨げられている。

## 根本原因の分析

### 1. Node.js側の自動再接続機能が無効化されている

**mcpUnity.ts (150-151行目)**
```typescript
// WebSocket closed. Reconnecting in
//setTimeout(this.connect, this.retryDelay);
```

WebSocketの`onclose`イベントハンドラーで、自動再接続のコードがコメントアウトされている。これにより、Unity側が再起動しても、Node.js側は再接続を試みない。

### 2. Unity側のドメインリロード処理

**McpUnityServer.cs**
- アセンブリリロード前：`OnBeforeAssemblyReload()`でサーバーを停止
- アセンブリリロード後：`OnAfterAssemblyReload()`で新しいサーバーを起動

この処理自体は正しいが、クライアント（Node.js）側が自動再接続しないため、新しいサーバーインスタンスに接続できない。

### 3. リソース管理の問題

- WebSocketServerの`Dispose()`が呼ばれない可能性
- ポートの解放が完全でない可能性（ただし`ReuseAddress = true`で緩和）

## 解決策

### 解決策1: Node.js側の自動再接続機能を有効化（推奨）

**メリット:**
- 最小限の変更で問題を解決
- Unity側の既存の動作を維持
- 他の切断シナリオにも対応可能

**実装方法:**

1. **mcpUnity.tsの修正**
```typescript
// oncloseイベントハンドラーの修正
ws.onclose = () => {
    this.logger.debug('WebSocket closed');
    
    // 意図的な切断でない場合は再接続
    if (!this.isDisconnecting) {
        this.logger.debug('Attempting to reconnect in', this.retryDelay, 'ms');
        setTimeout(() => {
            this.connect().catch(err => {
                this.logger.error('Reconnection failed:', err);
            });
        }, this.retryDelay);
    }
    
    // 既存の処理...
};
```

2. **再接続ロジックの改善**
```typescript
private async reconnect(): Promise<void> {
    this.disconnect();
    await new Promise(resolve => setTimeout(resolve, 100)); // 短い待機
    await this.connect();
}
```

3. **指数バックオフの実装**
```typescript
private reconnectAttempts = 0;
private maxReconnectAttempts = 10;

private calculateBackoff(): number {
    return Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
}
```

### 解決策2: Unity側でクライアントに再接続を通知

**メリット:**
- より制御された再接続
- Unity側の状態を考慮した接続管理

**実装方法:**

1. **再接続通知メカニズムの追加**
   - 特別なWebSocketメッセージを送信してクライアントに再接続を促す
   - ただし、接続が既に切断されている場合は機能しない

### 解決策3: 接続の維持（ドメインリロードを回避）

**メリット:**
- 接続が切断されない
- 最も安定した動作

**デメリット:**
- Unityの基本的な動作に反する
- 実装が複雑

**実装方法:**
- `[InitializeOnLoadMethod]`を使用してドメインリロード後も接続を維持
- WebSocketServerインスタンスをシリアライズ可能な形で保持

## 推奨される実装手順

### フェーズ1: 即座の修正（最小限の変更）

1. **mcpUnity.tsの修正**
```typescript
// oncloseハンドラーで自動再接続を有効化
ws.onclose = () => {
    this.logger.debug('WebSocket closed. Reconnecting in', this.retryDelay);
    setTimeout(() => this.connect().catch(err => 
        this.logger.error('Reconnection failed:', err)
    ), this.retryDelay);
    
    // 既存の処理
    this.pendingRequests.forEach(request => {
        request.reject(new McpError(
            ErrorCode.InternalError,
            'Connection closed before response received'
        ));
    });
    this.pendingRequests.clear();
};
```

### フェーズ2: 堅牢性の向上

1. **再接続の改善**
   - 指数バックオフの実装
   - 最大リトライ回数の設定
   - 接続状態の管理

2. **Unity側の改善**
   - WebSocketServerの適切なDispose
   - 接続状態の通知機能

3. **エラーハンドリングの強化**
   - 再接続失敗時の通知
   - ログの改善

## テスト計画

1. **基本的な再接続テスト**
   - Unityでコードを変更してリコンパイルを発生させる
   - Node.js側が自動的に再接続することを確認

2. **連続リコンパイルテスト**
   - 短時間に複数回リコンパイルを実行
   - 各回で適切に再接続されることを確認

3. **エラーケーステスト**
   - Unity側のサーバーが起動しない場合
   - ネットワークエラーが発生した場合

## 結論

この問題の根本原因は、Node.js側の自動再接続機能が無効化されていることである。最も簡単で効果的な解決策は、mcpUnity.tsの`onclose`イベントハンドラーで自動再接続を有効化することである。これにより、Unityのリコンパイル後も接続が自動的に回復し、連続的な開発ワークフローが可能になる。

長期的には、より堅牢な再接続メカニズム（指数バックオフ、状態管理など）を実装することで、さまざまな切断シナリオに対応できるようになる。