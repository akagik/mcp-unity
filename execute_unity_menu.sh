#!/bin/bash

# Execute Unity Menu
# Unity EditorのMenuItemをMCP経由で実行するスクリプト

set -e

# カラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 引数チェック
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <menu_path> [server_path]"
    echo ""
    echo "例:"
    echo "  $0 \"GameObject/Create Empty\""
    echo "  $0 \"Window/General/Console\""
    echo "  $0 \"Tools/ForceScriptReload\""
    echo "  $0 \"File/Save Project\" ./Server~/build/index.js"
    exit 1
fi

MENU_PATH="$1"
SERVER_PATH="${2:-}"

# サーバーを探す
if [ -n "$SERVER_PATH" ]; then
    BUILD_FILE="$SERVER_PATH"
elif [ -n "$MCP_SERVER_PATH" ]; then
    BUILD_FILE="$MCP_SERVER_PATH"
else
    # 自動検索
    for path in \
        "./Server~/build/index.js" \
        "./Packages/McpUnity/Server~/build/index.js" \
        "./Library/PackageCache/com.gamelovers.mcp-unity@*/Server~/build/index.js"
    do
        for expanded in $path; do
            if [ -f "$expanded" ]; then
                BUILD_FILE="$expanded"
                break 2
            fi
        done
    done
fi

if [ -z "$BUILD_FILE" ] || [ ! -f "$BUILD_FILE" ]; then
    echo -e "${RED}エラー: MCPサーバーが見つかりません${NC}"
    exit 1
fi

echo "Server: $BUILD_FILE"
echo "Menu: $MENU_PATH"
echo ""

# 一時ファイル
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# MCPメッセージを作成（EOFマーカーを使わない）
cat > "$TEMP_DIR/input" << 'ENDOFMESSAGE'
Content-Length: 146

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"0.1.0","capabilities":{"tools":{}},"clientInfo":{"name":"Test","version":"1.0"}}}
ENDOFMESSAGE

# Tool実行メッセージを追加（動的に生成）
MSG='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute_menu_item","arguments":{"menuPath":"'"$MENU_PATH"'"}}}'
LENGTH=${#MSG}
echo "Content-Length: $LENGTH" >> "$TEMP_DIR/input"
echo "" >> "$TEMP_DIR/input"
echo "$MSG" >> "$TEMP_DIR/input"

echo "送信中..."

# 実行（シンプルなタイムアウト）
{
    timeout 30 node "$BUILD_FILE" < "$TEMP_DIR/input" > "$TEMP_DIR/output" 2>/dev/null &
    PID=$!
    
    # 結果を待つ
    COUNT=0
    while [ $COUNT -lt 30 ]; do
        if ! kill -0 $PID 2>/dev/null; then
            break
        fi
        
        if [ -s "$TEMP_DIR/output" ] && grep -q '"id":2' "$TEMP_DIR/output" 2>/dev/null; then
            kill $PID 2>/dev/null || true
            break
        fi
        
        sleep 1
        COUNT=$((COUNT + 1))
        
        if [ $((COUNT % 5)) -eq 0 ]; then
            echo "待機中... ${COUNT}秒"
        fi
    done
    
    # プロセスがまだ生きていたら終了
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
} 2>/dev/null

# 結果確認
if [ ! -s "$TEMP_DIR/output" ]; then
    echo -e "${RED}レスポンスなし${NC}"
    exit 1
fi

# 結果を表示
echo ""
echo "レスポンス:"

# id:2のレスポンスを探して表示
RESPONSE=$(grep '"id":2' "$TEMP_DIR/output" 2>/dev/null || echo "")
if [ -n "$RESPONSE" ]; then
    # pythonで整形を試みる、失敗したら生データを表示
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    
    # 成功/失敗判定
    if echo "$RESPONSE" | grep -q '"error"'; then
        ERROR_MSG=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        echo -e "\n${RED}❌ エラー: ${ERROR_MSG}${NC}"
        exit 1
    elif echo "$RESPONSE" | grep -q 'Successfully'; then
        MSG=$(echo "$RESPONSE" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p')
        echo -e "\n${GREEN}✅ ${MSG}${NC}"
    elif echo "$RESPONSE" | grep -q 'Failed'; then
        MSG=$(echo "$RESPONSE" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p')
        echo -e "\n${RED}❌ ${MSG}${NC}"
        exit 1
    else
        echo -e "\n${GREEN}✅ 実行完了${NC}"
    fi
else
    echo -e "${RED}レスポンスなし${NC}"
    exit 1
fi