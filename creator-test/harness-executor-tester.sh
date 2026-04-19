#!/bin/bash
# harness-executor-tester.sh - Harness Executor 测试脚本
# 用法: ./harness-executor-tester.sh "<test_name>" "<prompt>" [project_path]
#
# 功能:
#   1. 在指定项目中执行 Claude Code，启用 harness-executor skill
#   2. 捕获 stream-json 输出
#   3. 解析并生成测试报告
#
# 输出:
#   - {test_name}/
#     - execution.log      (执行日志)
#     - stream_raw.jsonl   (原始流数据)
#     - thinking.txt       (思考过程)
#     - tool_calls.json    (工具调用统计)
#     - metrics.json       (token/duration/cost)
#     - final_output.txt   (最终输出)
#     - parse_status.json  (解析状态)

set +e

TEST_NAME="$1"
PROMPT="$2"
PROJECT_PATH="${3:-/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare}"
SKILL_PATH="/Users/josh_folder/harness-simple/skills/harness-executor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output-4/$TEST_NAME"

LOG_FILE="$OUTPUT_DIR/execution.log"
EXIT_CODE=0
CLAUDE_PID=""

if [ -z "$TEST_NAME" ] || [ -z "$PROMPT" ]; then
    echo "用法: $0 \"<test_name>\" \"<prompt>\" [project_path]"
    echo ""
    echo "示例:"
    echo "  $0 \"test-1-missing-agents\" \"修复 MarkdownFileType.swift 中的拼写错误\""
    echo "  $0 \"test-2-simple-task\" \"修复 README.md 中的 typo\""
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 初始化日志
{
    echo "=============================================="
    echo "Harness Executor 测试日志"
    echo "=============================================="
    echo "测试名称: $TEST_NAME"
    echo "时间: $(date -Iseconds)"
    echo "项目路径: $PROJECT_PATH"
    echo "Skill 路径: $SKILL_PATH"
    echo "输出目录: $OUTPUT_DIR"
    echo "=============================================="
} > "$LOG_FILE"

# 生成 session ID (必须是有效的 UUID)
SESSION_ID=$(python3 -c "import uuid; print(uuid.uuid4())")

echo "=============================================="
echo "Harness Executor 测试开始"
echo "=============================================="
echo "测试: $TEST_NAME"
echo "项目: $PROJECT_PATH"
echo "=============================================="

# 输出文件路径
STREAM_FILE="$OUTPUT_DIR/stream_raw.jsonl"
METRICS_FILE="$OUTPUT_DIR/metrics.json"
THINKING_FILE="$OUTPUT_DIR/thinking.txt"
TOOLS_FILE="$OUTPUT_DIR/tool_calls.json"
OUTPUT_FILE="$OUTPUT_DIR/final_output.txt"
PARTIAL_FILE="$OUTPUT_DIR/.stream_partial.jsonl"

# 标记开始
echo "START_TIME=$(date +%s)" >> "$LOG_FILE"
echo "STATUS=STARTING" >> "$LOG_FILE"

# -----------------------------------
# Trap 处理函数
# -----------------------------------
save_intermediate_state() {
    local reason="${1:-UNKNOWN}"
    echo "" | tee -a "$LOG_FILE"
    echo "!!! TRAP 触发: $reason" | tee -a "$LOG_FILE"

    if [ -n "$CLAUDE_PID" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
        echo "!!! 终止 Claude 进程 (PID: $CLAUDE_PID)" | tee -a "$LOG_FILE"
        kill -TERM "$CLAUDE_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$CLAUDE_PID" 2>/dev/null || true
    fi

    if [ -f "$PARTIAL_FILE" ] && [ -s "$PARTIAL_FILE" ]; then
        cat "$PARTIAL_FILE" >> "$STREAM_FILE" 2>/dev/null || true
    fi

    echo "STATUS=INTERRUPTED" >> "$LOG_FILE"
    echo "END_TIME=$(date +%s)" >> "$LOG_FILE"
    EXIT_CODE=130
}

trap 'save_intermediate_state "SIGINT (Ctrl+C)"; exit 130' INT
trap 'save_intermediate_state "SIGTERM"; exit 143' TERM
trap 'save_intermediate_state "UNEXPECTED_ERROR"; exit 1' EXIT

# 切换到项目目录执行
cd "$PROJECT_PATH"

echo "" | tee -a "$LOG_FILE"
echo ">>> 开始执行 Claude Code (启用 harness-executor)..." | tee -a "$LOG_FILE"
echo ""

# 构建 claude code 命令
# 注意：这里通过环境变量指定 skill，或者通过 --system flag
CLAUDE_CMD="claude code --print --verbose --output-format stream-json --session-id $SESSION_ID --dangerously-skip-permissions"

# 执行 Claude Code
{
    echo "$PROMPT" | $CLAUDE_CMD 2>&1
    echo "CLAUDE_EXIT_CODE=$?" >> "$LOG_FILE"
} | tee "$PARTIAL_FILE" > "$STREAM_FILE" &
CLAUDE_PID=$!

echo ">>> Claude 进程 PID: $CLAUDE_PID" | tee -a "$LOG_FILE"

# 等待完成
wait "$CLAUDE_PID"
CLAUDE_EXIT=$?
CLAUDE_PID=""

echo ">>> Claude 进程退出，代码: $CLAUDE_EXIT" | tee -a "$LOG_FILE"

rm -f "$PARTIAL_FILE"

STREAM_SIZE=$(wc -c < "$STREAM_FILE" 2>/dev/null || echo 0)
echo ">>> stream 大小: $STREAM_SIZE bytes" | tee -a "$LOG_FILE"

echo "STATUS=EXECUTED" >> "$LOG_FILE"
echo "STREAM_SIZE=$STREAM_SIZE" >> "$LOG_FILE"

# 解析结果
echo "STATUS=PARSING" >> "$LOG_FILE"
if [ -f "$STREAM_FILE" ] && [ -s "$STREAM_FILE" ]; then
    python3 "$SCRIPT_DIR/parse-results.py" "$STREAM_FILE" "$OUTPUT_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

echo ""
echo "=============================================="
echo "执行完成"
echo "=============================================="
echo ""
echo "输出文件:"
ls -la "$OUTPUT_DIR"
echo ""
echo "=== Metrics ==="
cat "$METRICS_FILE" 2>/dev/null || echo "(无 metrics)"
echo ""
echo "=== Tool Calls ==="
cat "$TOOLS_FILE" 2>/dev/null || echo "(无 tool calls)"
echo ""
echo "=== Thinking (前500字符) ==="
head -c 500 "$THINKING_FILE" 2>/dev/null || echo "(无thinking输出)"
echo "..."
echo ""
echo "=== Final Output (前2000字符) ==="
cat "$OUTPUT_FILE" 2>/dev/null | head -c 2000 || echo "(无输出)"
echo ""

# 检查错误
echo "STATUS=CHECKING_ERRORS" >> "$LOG_FILE"

if grep -q '"error"' "$STREAM_FILE" 2>/dev/null; then
    echo "!!! 检测到 stream 中的 error" | tee -a "$LOG_FILE"
    EXIT_CODE=1
fi

if [ "$CLAUDE_EXIT" -ne 0 ] && [ "$CLAUDE_EXIT" -lt 128 ]; then
    echo "!!! Claude 进程异常退出: $CLAUDE_EXIT" | tee -a "$LOG_FILE"
    EXIT_CODE=$CLAUDE_EXIT
fi

echo "STATUS=FINISHED" >> "$LOG_FILE"
echo "END_TIME=$(date +%s)" >> "$LOG_FILE"
echo "FINAL_EXIT_CODE=$EXIT_CODE" >> "$LOG_FILE"

echo ""
echo "=============================================="
echo "测试结束"
echo "=============================================="
echo "日志文件: $LOG_FILE"

trap - INT TERM EXIT

if [ $EXIT_CODE -eq 0 ]; then
    echo "STATUS=OK"
else
    echo "STATUS=ERROR (code: $EXIT_CODE)"
fi

exit $EXIT_CODE
