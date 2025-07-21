リコンパイル後に以下のログが最後に出ているのを確認。

```
[MCP Unity] WebSocket server stopped and resources cleaned up. 
```

その後、サーバーが再起動することなく、mcp-server との接続が途絶えます。

その後、Unity Editor をアクティブにすると

```
[MCP Unity] WebSocket server started successfully on localhost:8090.
```

といったサーバー起動のログが出現します。

つまり、まだ非アクティブ状態でのサーバー起動に成功していません。原因をさらに深く調査して、問題を解決してください。Think harder.