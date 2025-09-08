#!/bin/bash

# Unity MCP Console Logs Getter
# Unityのコンソールログを取得するスクリプト
#
# 使用方法:
#   ./get_console_logs.sh                    # 最新10件のログを取得
#   ./get_console_logs.sh 20                 # 最新20件のログを取得
#   ./get_console_logs.sh error              # エラーログのみ
#   ./get_console_logs.sh warning 5          # 警告ログを5件

set -e

# カラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# デフォルト設定
LOG_TYPE=""
LIMIT=10
SERVER_PATH="${MCP_SERVER_PATH:-}"

# 引数解析
if [ $# -ge 1 ]; then
    # 数字のみの場合はlimit
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        LIMIT="$1"
    # error/warning/infoの場合はlogType
    elif [[ "$1" =~ ^(error|warning|info)$ ]]; then
        LOG_TYPE="$1"
        # 第2引数があればlimit
        if [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
            LIMIT="$2"
        fi
    # サーバーパス指定
    elif [ -f "$1" ]; then
        SERVER_PATH="$1"
        shift
        # 残りの引数を再解析
        if [ $# -ge 1 ]; then
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                LIMIT="$1"
            elif [[ "$1" =~ ^(error|warning|info)$ ]]; then
                LOG_TYPE="$1"
                if [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    LIMIT="$2"
                fi
            fi
        fi
    fi
fi

# サーバーを探す
if [ -z "$SERVER_PATH" ]; then
    # 自動検索
    for path in \
        "./Server~/build/index.js" \
        "./Packages/McpUnity/Server~/build/index.js" \
        "./Library/PackageCache/com.gamelovers.mcp-unity@*/Server~/build/index.js"
    do
        for expanded in $path; do
            if [ -f "$expanded" ]; then
                SERVER_PATH="$expanded"
                break 2
            fi
        done
    done
fi

if [ -z "$SERVER_PATH" ] || [ ! -f "$SERVER_PATH" ]; then
    echo -e "${RED}エラー: MCPサーバーが見つかりません${NC}"
    echo ""
    echo "使用方法:"
    echo "  $0 [logType] [limit]"
    echo "  $0 [server_path] [logType] [limit]"
    echo ""
    echo "例:"
    echo "  $0                    # 最新10件"
    echo "  $0 20                 # 最新20件"
    echo "  $0 error              # エラーログのみ"
    echo "  $0 warning 5          # 警告5件"
    echo "  $0 ./Server~/build/index.js error 10"
    exit 1
fi

echo -e "${CYAN}Unity Console Logs${NC}"
echo "Server: $SERVER_PATH"
if [ -n "$LOG_TYPE" ]; then
    echo "Type: $LOG_TYPE"
fi
echo "Limit: $LIMIT"
echo "=================="
echo ""

# 一時ファイル
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# リソースURIを構築（単純なURIを使用）
RESOURCE_URI="unity://console-logs"

# MCPメッセージを作成
cat > "$TEMP_DIR/input" << 'ENDOFMESSAGE'
Content-Length: 146

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"0.1.0","capabilities":{"tools":{}},"clientInfo":{"name":"LogReader","version":"1.0"}}}
ENDOFMESSAGE

# get_console_logs ツールを使用
if [ -n "$LOG_TYPE" ]; then
    MSG="{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"get_console_logs\",\"arguments\":{\"logType\":\"$LOG_TYPE\",\"limit\":$LIMIT,\"includeStackTrace\":false}}}"
else
    MSG="{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"get_console_logs\",\"arguments\":{\"limit\":$LIMIT,\"includeStackTrace\":false}}}"
fi
LENGTH=${#MSG}
echo "Content-Length: $LENGTH" >> "$TEMP_DIR/input"
echo "" >> "$TEMP_DIR/input"
echo "$MSG" >> "$TEMP_DIR/input"

# 実行（バックグラウンドでタイムアウトプロセスを制御）
{
    timeout 10 node "$SERVER_PATH" < "$TEMP_DIR/input" > "$TEMP_DIR/output" 2>/dev/null &
    PID=$!
    
    # 結果を待つ
    COUNT=0
    while [ $COUNT -lt 10 ]; do
        if ! kill -0 $PID 2>/dev/null; then
            break
        fi
        
        if [ -s "$TEMP_DIR/output" ] && grep -q '"id":2' "$TEMP_DIR/output" 2>/dev/null; then
            kill $PID 2>/dev/null || true
            break
        fi
        
        sleep 0.5
        COUNT=$((COUNT + 1))
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

# レスポンスを解析して表示
RESPONSE=$(grep '"id":2' "$TEMP_DIR/output" 2>/dev/null || echo "")

if [ -z "$RESPONSE" ]; then
    echo -e "${RED}有効なレスポンスが見つかりません${NC}"
    exit 1
fi

# エラーチェック
if echo "$RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo "$RESPONSE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    echo -e "${RED}エラー: ${ERROR_MSG}${NC}"
    exit 1
fi

# ログを抽出して表示
if echo "$RESPONSE" | grep -q '"content"'; then
    # contentからテキストを抽出（エスケープされたJSON）
    LOGS_JSON=$(echo "$RESPONSE" | sed -n 's/.*"text":"\(.*\)"}].*/\1/p')
    
    # JSONをパースして表示（Python利用）
    if command -v python3 > /dev/null 2>&1; then
        echo "$LOGS_JSON" | python3 -c "
import sys
import json

try:
    # エスケープされた改行を処理
    input_str = sys.stdin.read()
    input_str = input_str.replace('\\\\n', '\\n').replace('\\\\\"', '\"')
    
    # JSON配列として直接解析
    logs = json.loads(input_str)
    
    if not logs:
        print('ログがありません')
    else:
        for log in logs:
            timestamp = log.get('timestamp', 'N/A')
            log_type = log.get('type', 'Log')
            message = log.get('message', '')
            
            # タイプによって色を変える
            if log_type == 'Error':
                color = '\033[0;31m'  # 赤
                symbol = '❌'
            elif log_type == 'Warning':
                color = '\033[1;33m'  # 黄
                symbol = '⚠️ '
            else:
                color = '\033[0;36m'  # シアン
                symbol = '📝'
            
            print(f'{color}[{timestamp}] {symbol} {message}\033[0m')
            
except Exception as e:
    # パース失敗時は生データを表示
    print('=== Raw Logs ===')
    print(input_str)
" 2>/dev/null || {
        # Pythonが失敗した場合は簡易表示
        echo "=== Logs (Raw) ==="
        echo "$LOGS_JSON" | sed 's/},{/}\n{/g' | sed 's/^\[{/{/' | sed 's/}]$/}/'
    }
    else
        # Pythonがない場合
        echo "=== Logs (Simple) ==="
        # メッセージだけを抽出
        echo "$RESPONSE" | grep -o '"message":"[^"]*"' | sed 's/"message":"//' | sed 's/"$//'
    fi
else
    echo -e "${YELLOW}ログが見つかりません${NC}"
fi

echo ""
echo -e "${GREEN}✅ 完了${NC}"