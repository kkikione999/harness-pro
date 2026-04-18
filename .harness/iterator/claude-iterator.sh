#!/bin/bash
# claude-iterator.sh - Claude Code 迭代执行与监控脚本
# 用法: ./claude-iterator.sh "<prompt>" [output_dir]
# 输出:
#   - thinking.txt     (思考过程)
#   - tool_calls.json  (工具调用序列)
#   - metrics.json     (token/duration/cost)
#   - final_output.txt (最终结果)
#   - stream_raw.jsonl (原始流数据)
#
# 异常处理:
#   - trap 捕获 SIGINT/SIGTERM，保存中间状态
#   - 渐进式写入 stream，随时可中断
#   - 分阶段错误检测，不漏掉中间错误

# 允许命令失败时不立即退出（trap 会处理）
set +e

PROMPT="$1"
OUTPUT_DIR="${2:-.harness/iterator/output/$(date +%Y%m%d_%H%M%S)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$OUTPUT_DIR/execution.log"

# 退出状态
EXIT_CODE=0
CLAUDE_PID=""

if [ -z "$PROMPT" ]; then
    echo "用法: $0 \"<prompt>\" [output_dir]"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 初始化日志文件
{
    echo "=============================================="
    echo "Claude Iterator 执行日志"
    echo "=============================================="
    echo "时间: $(date -Iseconds)"
    echo "输出目录: $OUTPUT_DIR"
    echo "Prompt: ${PROMPT:0:200}..."
    echo "=============================================="
} > "$LOG_FILE"

# 生成有效的 UUID 作为 session ID
SESSION_ID=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "iter-$$-$(date +%s)")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=============================================="
echo "Claude Iterator 开始执行"
echo "=============================================="
echo "时间: $TIMESTAMP"
echo "Session: $SESSION_ID"
echo "输出目录: $OUTPUT_DIR"
echo "Prompt: ${PROMPT:0:100}..."
echo "=============================================="

# 输出文件路径
STREAM_FILE="$OUTPUT_DIR/stream_raw.jsonl"
METRICS_FILE="$OUTPUT_DIR/metrics.json"
THINKING_FILE="$OUTPUT_DIR/thinking.txt"
TOOLS_FILE="$OUTPUT_DIR/tool_calls.json"
OUTPUT_FILE="$OUTPUT_DIR/final_output.txt"
PARTIAL_FILE="$OUTPUT_DIR/.stream_partial.jsonl"

# 标记执行开始
echo "START_TIME=$(date +%s)" >> "$LOG_FILE"
echo "SESSION_ID=$SESSION_ID" >> "$LOG_FILE"
echo "STATUS=STARTING" >> "$LOG_FILE"

# -----------------------------------
# Trap 处理函数 - 异常时保存状态
# -----------------------------------
save_intermediate_state() {
    local reason="${1:-UNKNOWN}"
    echo "" | tee -a "$LOG_FILE"
    echo "!!! TRAP 触发: $reason" | tee -a "$LOG_FILE"
    echo "!!! 时间: $(date -Iseconds)" | tee -a "$LOG_FILE"

    # 杀掉 Claude 进程（如果还在运行）
    if [ -n "$CLAUDE_PID" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
        echo "!!! 终止 Claude 进程 (PID: $CLAUDE_PID)" | tee -a "$LOG_FILE"
        kill -TERM "$CLAUDE_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$CLAUDE_PID" 2>/dev/null || true
    fi

    # 如果有 partial 数据，合并到 stream
    if [ -f "$PARTIAL_FILE" ] && [ -s "$PARTIAL_FILE" ]; then
        echo "!!! 发现 partial 数据，保存到 stream" | tee -a "$LOG_FILE"
        cat "$PARTIAL_FILE" >> "$STREAM_FILE" 2>/dev/null || true
    fi

    # 尝试解析已有数据
    if [ -f "$STREAM_FILE" ] && [ -s "$STREAM_FILE" ]; then
        echo "!!! 尝试解析已有的 stream 数据" | tee -a "$LOG_FILE"
        python3 "$SCRIPT_DIR/parse-results.py" "$STREAM_FILE" "$OUTPUT_DIR" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "!!! 部分解析成功" | tee -a "$LOG_FILE"
        fi
    fi

    # 写入中断标记
    {
        echo ""
        echo "=============================================="
        echo "执行被中断"
        echo "原因: $reason"
        echo "时间: $(date -Iseconds)"
        echo "Stream 文件: $STREAM_FILE ($(wc -c < "$STREAM_FILE" 2>/dev/null || echo 0) bytes)"
        echo "=============================================="
    } >> "$LOG_FILE"

    # 标记状态为中断
    echo "STATUS=INTERRUPTED" >> "$LOG_FILE"
    echo "END_TIME=$(date +%s)" >> "$LOG_FILE"

    EXIT_CODE=130  # SIGINT
}

# 设置 trap
trap 'save_intermediate_state "SIGINT (Ctrl+C)"; exit 130' INT
trap 'save_intermediate_state "SIGTERM"; exit 143' TERM
trap 'save_intermediate_state "UNEXPECTED_ERROR"; exit 1' EXIT

echo ""
echo ">>> 开始执行 Claude Code..."
echo ""

# 执行 Claude Code - 使用 tee 渐进式写入
# 使用临时文件接收 stderr，记录 PID
{
    echo "$PROMPT" | claude code --print --verbose --output-format stream-json \
        --session-id "$SESSION_ID" \
        --dangerously-skip-permissions \
        2>&1
    echo "CLAUDE_EXIT_CODE=$?" >> "$LOG_FILE"
} | tee "$PARTIAL_FILE" > "$STREAM_FILE" &
CLAUDE_PID=$!

echo ">>> Claude 进程 PID: $CLAUDE_PID" | tee -a "$LOG_FILE"

# 等待进程完成，同时监控
wait "$CLAUDE_PID"
CLAUDE_EXIT=$?
CLAUDE_PID=""  # 进程已结束，清除 PID

echo ">>> Claude 进程退出，代码: $CLAUDE_EXIT" | tee -a "$LOG_FILE"

# 删除 partial 文件
rm -f "$PARTIAL_FILE"

STREAM_SIZE=$(wc -c < "$STREAM_FILE" 2>/dev/null || echo 0)
echo ">>> stream 大小: $STREAM_SIZE bytes" | tee -a "$LOG_FILE"

# 更新日志状态
echo "STATUS=EXECUTED" >> "$LOG_FILE"
echo "STREAM_SIZE=$STREAM_SIZE" >> "$LOG_FILE"

# 检查 stream 是否完整
if ! grep -q '"type":"result"' "$STREAM_FILE" 2>/dev/null; then
    echo "!!! 警告: stream 数据可能不完整（缺少 result 事件）" | tee -a "$LOG_FILE"
    echo "STATUS=INCOMPLETE" >> "$LOG_FILE"
fi

# 解析结果
echo "STATUS=PARSING" >> "$LOG_FILE"
if [ -f "$STREAM_FILE" ] && [ -s "$STREAM_FILE" ]; then
    python3 "$SCRIPT_DIR/parse-results.py" "$STREAM_FILE" "$OUTPUT_DIR" 2>&1 | tee -a "$LOG_FILE"
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo ">>> 解析完成" | tee -a "$LOG_FILE"
    else
        echo "!!! 解析失败，继续执行" | tee -a "$LOG_FILE"
    fi
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

# 分阶段错误检测
echo "STATUS=CHECKING_ERRORS" >> "$LOG_FILE"

# 检查 stream 错误
if grep -q '"error"' "$STREAM_FILE" 2>/dev/null; then
    echo "!!! 检测到 stream 中的 error" | tee -a "$LOG_FILE"
    EXIT_CODE=1
fi

# 检查 metrics 错误
if [ -f "$METRICS_FILE" ]; then
    if grep -q '"error"' "$METRICS_FILE" 2>/dev/null; then
        echo "!!! 检测到 metrics 中的 error" | tee -a "$LOG_FILE"
        EXIT_CODE=1
    fi
fi

# 检查 Claude 退出码
if [ "$CLAUDE_EXIT" -ne 0 ] && [ "$CLAUDE_EXIT" -lt 128 ]; then
    echo "!!! Claude 进程异常退出: $CLAUDE_EXIT" | tee -a "$LOG_FILE"
    EXIT_CODE=$CLAUDE_EXIT
fi

# 检查 stream 是否不完整
if ! grep -q '"type":"result"' "$STREAM_FILE" 2>/dev/null; then
    echo "!!! Stream 不完整，可能丢失数据" | tee -a "$LOG_FILE"
    # 不改变 EXIT_CODE，因为可能是用户中断
fi

# 完成日志
echo "STATUS=FINISHED" >> "$LOG_FILE"
echo "END_TIME=$(date +%s)" >> "$LOG_FILE"
echo "FINAL_EXIT_CODE=$EXIT_CODE" >> "$LOG_FILE"

echo ""
echo "=============================================="
echo "执行结束"
echo "=============================================="
echo "日志文件: $LOG_FILE"

# 清除 trap（正常结束）
trap - INT TERM EXIT

if [ $EXIT_CODE -eq 0 ]; then
    echo "STATUS=OK"
    echo "METRICS_FILE=$METRICS_FILE"
else
    echo "STATUS=ERROR (code: $EXIT_CODE)"
fi

exit $EXIT_CODE