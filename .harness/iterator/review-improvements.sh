#!/bin/bash
# review-improvements.sh - 查看并管理改进提案
# 用法: ./review-improvements.sh [--adopt <id>] [--reject <id>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVOLUTION_DIR="$SCRIPT_DIR/evolution"
PENDING_DIR="$EVOLUTION_DIR/improvements/pending"
ADOPTED_DIR="$EVOLUTION_DIR/improvements/adopted"
REJECTED_DIR="$EVOLUTION_DIR/improvements/rejected"

show_help() {
    echo "用法: $0 <命令> [参数]"
    echo ""
    echo "命令:"
    echo "  list                    列出所有改进提案"
    echo "  show <id>               显示提案详情"
    echo "  adopt <id>              采纳提案"
    echo "  reject <id>             拒绝提案"
    echo "  apply <id>              采纳并执行（应用变更到 skill）"
    echo ""
    echo "示例:"
    echo "  $0 list"
    echo "  $0 show 20260418_143022_1-context_overload-0"
    echo "  $0 adopt 20260418_143022_1-context_overload-0"
    echo "  $0 apply 20260418_143022_1-context_overload-0"
}

list_pending() {
    echo "## 待处理改进提案"
    echo ""

    if [[ -z "$(ls -A "$PENDING_DIR" 2>/dev/null)" ]]; then
        echo "(无待处理提案)"
        return
    fi

    for file in "$PENDING_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            basename "$file"
            # 提取关键信息
            title=$(grep "^# 改进提案" "$file" | head -1 || echo "无标题")
            skill=$(grep "\*\*影响 Skill\*\*:" "$file" | sed 's/.*: *//' || echo "未知")
            risk=$(grep "\*\*风险等级\*\*:" "$file" | sed 's/.*: *//' || echo "未知")
            echo "  - $title | Skill: $skill | 风险: $risk"
            echo ""
        fi
    done
}

show_proposal() {
    local id="$1"
    local file="$PENDING_DIR/${id}.md"

    if [[ ! -f "$file" ]]; then
        echo "错误: 提案不存在: $id"
        exit 1
    fi

    cat "$file"
}

adopt_proposal() {
    local id="$1"
    local src="$PENDING_DIR/${id}.md"
    local dst="$ADOPTED_DIR/${id}.md"

    if [[ ! -f "$src" ]]; then
        echo "错误: 提案不存在: $id"
        exit 1
    fi

    mv "$src" "$dst"
    echo "✅ 已采纳提案: $id"

    # 更新棘轮 level
    update_ratchet_level

    echo ""
    echo "📋 下一步:"
    echo "  运行 './apply-improvement.sh $id' 来应用变更"
}

reject_proposal() {
    local id="$1"
    local src="$PENDING_DIR/${id}.md"
    local dst="$REJECTED_DIR/${id}.md"

    if [[ ! -f "$src" ]]; then
        echo "错误: 提案不存在: $id"
        exit 1
    fi

    mv "$src" "$dst"
    echo "✅ 已拒绝提案: $id"
}

update_ratchet_level() {
    local state_file="$EVOLUTION_DIR/state.md"

    if [[ -f "$state_file" ]]; then
        # 读取当前 level
        current_level=$(grep "Level:" "$state_file" | sed 's/.*: *//')
        new_level=$((current_level + 1))

        # 替换
        sed -i '' "s/Level: $current_level/Level: $new_level/" "$state_file"
        echo "📈 Ratchet Level: $current_level → $new_level"
    fi
}

# 主逻辑
CMD="${1:-}"

if [[ -z "$CMD" ]] || [[ "$CMD" == "--help" ]] || [[ "$CMD" == "-h" ]]; then
    show_help
    exit 0
fi

case "$CMD" in
    list)
        list_pending
        ;;
    show)
        if [[ -z "$2" ]]; then
            echo "错误: 缺少提案 ID"
            exit 1
        fi
        show_proposal "$2"
        ;;
    adopt)
        if [[ -z "$2" ]]; then
            echo "错误: 缺少提案 ID"
            exit 1
        fi
        adopt_proposal "$2"
        ;;
    reject)
        if [[ -z "$2" ]]; then
            echo "错误: 缺少提案 ID"
            exit 1
        fi
        reject_proposal "$2"
        ;;
    apply)
        echo "注意: apply 命令需要手动执行 skill 变更"
        echo "请查看提案详情并手动应用变更"
        echo ""
        if [[ -n "$2" ]]; then
            show_proposal "$2"
        fi
        ;;
    *)
        echo "未知命令: $CMD"
        show_help
        exit 1
        ;;
esac
