#!/bin/bash
# run-evaluation.sh - 迭代评估主入口
# 用法: ./run-evaluation.sh <case_file> [--iterations N] [--skip-improvements]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ITERATOR_DIR="$(dirname "$SCRIPT_DIR")"

# 默认参数
CASE_FILE=""
ITERATIONS=1
SKIP_IMPROVEMENTS=false
OUTPUT_DIR=""
EVOLUTION_DIR=""

# 解析参数
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --iterations|--iterations=*)
            if [[ $1 == "--iterations=*" ]]; then
                ITERATIONS="${1#*=}"
            else
                ITERATIONS="$2"
                shift
            fi
            ;;
        --skip-improvements)
            SKIP_IMPROVEMENTS=true
            ;;
        --output-dir|--output-dir=*)
            if [[ $1 == "--output-dir=*" ]]; then
                OUTPUT_DIR="${1#*=}"
            else
                OUTPUT_DIR="$2"
                shift
            fi
            ;;
        --evolution-dir|--evolution-dir=*)
            if [[ $1 == "--evolution-dir=*" ]]; then
                EVOLUTION_DIR="${1#*=}"
            else
                EVOLUTION_DIR="$2"
                shift
            fi
            ;;
        --help|-h)
            echo "用法: $0 <case_file> [选项]"
            echo ""
            echo "选项:"
            echo "  --iterations N              迭代次数（默认: 1）"
            echo "  --skip-improvements         跳过改进提案生成"
            echo "  --output-dir <dir>          输出目录"
            echo "  --evolution-dir <dir>       进化状态目录"
            echo "  --help, -h                  显示此帮助"
            echo ""
            echo "示例:"
            echo "  $0 ../creator-executor-research/case-distributed-order-management.md"
            echo "  $0 case.md --iterations 3"
            exit 0
            ;;
        -*)
            echo "未知选项: $1"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            ;;
    esac
    shift
done

set -- "${POSITIONAL_ARGS[@]}"

if [[ ${#POSITIONAL_ARGS[@]} -eq 0 ]]; then
    echo "错误: 缺少 case_file 参数"
    echo "用法: $0 <case_file> [--iterations N] [--skip-improvements]"
    exit 1
fi

CASE_FILE="${POSITIONAL_ARGS[0]}"

# 解析绝对路径
CASE_FILE="$(cd "$(dirname "$CASE_FILE")" && pwd)/$(basename "$CASE_FILE")"

if [[ ! -f "$CASE_FILE" ]]; then
    echo "错误: Case 文件不存在: $CASE_FILE"
    exit 1
fi

# 设置默认目录
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/output"
fi

if [[ -z "$EVOLUTION_DIR" ]]; then
    EVOLUTION_DIR="$SCRIPT_DIR/evolution"
fi

echo "=============================================="
echo "Harness Iterator 迭代评估"
echo "=============================================="
echo "Case 文件: $CASE_FILE"
echo "输出目录: $OUTPUT_DIR"
echo "进化目录: $EVOLUTION_DIR"
echo "迭代次数: $ITERATIONS"
echo "跳过改进: $SKIP_IMPROVEMENTS"
echo "=============================================="

# 创建目录
mkdir -p "$OUTPUT_DIR"
mkdir -p "$EVOLUTION_DIR"
mkdir -p "$EVOLUTION_DIR/improvements/adopted"
mkdir -p "$EVOLUTION_DIR/improvements/pending"
mkdir -p "$EVOLUTION_DIR/improvements/rejected"

# 初始化进化状态
if [[ ! -f "$EVOLUTION_DIR/state.md" ]]; then
    cat > "$EVOLUTION_DIR/state.md" << 'EOF'
# Harness Evolution State

## Current Ratchet Level
Level: 0

## Evolution History

*No history yet*
EOF
    echo "✅ 初始化进化状态文件"
fi

# 运行 Python 迭代管理器
cd "$SCRIPT_DIR"

python3 iteration_manager.py \
    "$CASE_FILE" \
    --output-dir "$OUTPUT_DIR" \
    --evolution-dir "$EVOLUTION_DIR" \
    --iterations "$ITERATIONS" \
    $([[ "$SKIP_IMPROVEMENTS" == "true" ]] && echo "--skip-improvements")

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo ""
    echo "=============================================="
    echo "✅ 迭代完成"
    echo "=============================================="
else
    echo ""
    echo "=============================================="
    echo "⚠️ 迭代完成（但有错误）"
    echo "=============================================="
fi

exit $EXIT_CODE
