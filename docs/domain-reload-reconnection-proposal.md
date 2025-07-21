# ドメインリロード時の自動再接続機能の実装提案

## 現状の問題

1. **Unity側**: ドメインリロード時にWebSocketServerを停止・再起動する（これは必須）
2. **Node.js側**: 自動再接続のコードがコメントアウトされている
3. **結果**: ドメインリロード後、手動でNode.jsクライアントを再起動する必要がある

## 解決策: Node.js側での自動再接続の実装

### 1. mcpUnity.tsの修正

```typescript
// mcpUnity.ts の onclose ハンドラーを修正
this.ws.onclose = () => {
  this.logger.debug('WebSocket closed');
  this.disconnect();
  
  // 自動再接続を有効化
  if (!this.isShuttingDown) {
    this.logger.info(`WebSocket closed. Reconnecting in ${this.retryDelay}ms...`);
    setTimeout(() => this.reconnect(), this.retryDelay);
  }
};
```

### 2. 再接続戦略の実装

```typescript
export class McpUnity {
  private retryDelay = 1000;
  private maxRetryDelay = 30000; // 最大30秒
  private retryCount = 0;
  private isShuttingDown = false;
  
  private reconnect(): void {
    if (this.isShuttingDown) return;
    
    this.retryCount++;
    
    // エクスポネンシャルバックオフ
    this.retryDelay = Math.min(
      this.retryDelay * 2,
      this.maxRetryDelay
    );
    
    this.logger.info(`Reconnection attempt #${this.retryCount}`);
    
    this.connect().then(() => {
      // 接続成功時はリトライカウンターをリセット
      this.retryCount = 0;
      this.retryDelay = 1000;
      this.logger.info('Successfully reconnected to Unity');
    }).catch((error) => {
      this.logger.warn(`Reconnection failed: ${error.message}`);
      // connectメソッド内で次の再接続がスケジュールされる
    });
  }
  
  /**
   * 完全なシャットダウン時の処理
   */
  public shutdown(): void {
    this.isShuttingDown = true;
    this.disconnect();
  }
}
```

### 3. 接続状態の管理

```typescript
export enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting'
}

export class McpUnity {
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  
  public getConnectionState(): ConnectionState {
    return this.connectionState;
  }
  
  private async connect(): Promise<void> {
    this.connectionState = this.retryCount > 0 
      ? ConnectionState.RECONNECTING 
      : ConnectionState.CONNECTING;
    
    // ... 既存の接続ロジック ...
    
    this.ws.onopen = () => {
      this.connectionState = ConnectionState.CONNECTED;
      this.logger.debug('WebSocket connected');
      resolve();
    };
    
    this.ws.onclose = () => {
      this.connectionState = ConnectionState.DISCONNECTED;
      // ... 再接続ロジック ...
    };
  }
}
```

### 4. ペンディングリクエストの処理

```typescript
private handleReconnection(): void {
  // 既存のペンディングリクエストに対してエラーを返す
  for (const [id, request] of this.pendingRequests.entries()) {
    clearTimeout(request.timeout);
    request.reject(new McpUnityError(
      ErrorType.CONNECTION, 
      'Connection lost during domain reload. Please retry.'
    ));
  }
  this.pendingRequests.clear();
  
  // クライアントに再接続を通知
  this.emit('reconnected');
}
```

## Unity側の改善提案

### 1. 接続状態の永続化

```csharp
// ドメインリロード前に接続情報を保存
private static void OnBeforeAssemblyReload()
{
    if (Instance.IsListening)
    {
        // 接続中のクライアント情報を保存
        var connectedClients = Instance.Clients.Select(c => new {
            Id = c.Key,
            Name = c.Value
        }).ToList();
        
        SessionState.SetString("McpUnity_ConnectedClients", 
            JsonUtility.ToJson(connectedClients));
        
        Instance.StopServer();
    }
}

// ドメインリロード後に状態を復元
private static void OnAfterAssemblyReload()
{
    if (McpUnitySettings.Instance.AutoStartServer && !Instance.IsListening)
    {
        Instance.StartServer();
        
        // 保存されたクライアント情報をログ出力
        var clientsJson = SessionState.GetString("McpUnity_ConnectedClients", "[]");
        McpLogger.LogInfo($"Previous clients before reload: {clientsJson}");
    }
}
```

### 2. グレースフルシャットダウン

```csharp
public void StopServer()
{
    if (!IsListening) return;
    
    try
    {
        // 接続中のクライアントに通知
        foreach (var session in _webSocketServer.WebSocketServices["/McpUnity"].Sessions.Sessions)
        {
            try
            {
                var notification = new JObject
                {
                    ["type"] = "server_shutdown",
                    ["reason"] = "domain_reload",
                    ["reconnect_after"] = 2000 // 2秒後に再接続を推奨
                };
                session.Send(notification.ToString());
            }
            catch { }
        }
        
        // 短い待機時間を設けて、メッセージが送信されるのを待つ
        Thread.Sleep(100);
        
        _webSocketServer?.Stop();
        McpLogger.LogInfo("WebSocket server stopped gracefully");
    }
    catch (Exception ex)
    {
        McpLogger.LogError($"Error during graceful shutdown: {ex.Message}");
    }
}
```

## 実装の優先順位

1. **必須**: Node.js側の自動再接続機能の有効化
2. **推奨**: エクスポネンシャルバックオフの実装
3. **オプション**: Unity側のグレースフルシャットダウン
4. **オプション**: 接続状態の永続化とログ出力

## まとめ

- WebSocketServerをドメインリロード間で維持することは技術的に不可能
- しかし、Node.js側の自動再接続機能により、ユーザー体験を大幅に改善可能
- 実装は比較的シンプルで、既存のコードへの影響も最小限