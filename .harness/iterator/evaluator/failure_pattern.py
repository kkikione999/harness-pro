#!/usr/bin/env python3
"""
failure_pattern.py - 失败模式识别器

跨 iteration 分析失败模式，
识别系统性的 skill 链路缺陷。
"""

import json
import os
from typing import Dict, List, Any, Optional, Set
from dataclasses import dataclass
from collections import defaultdict
from datetime import datetime


@dataclass
class FailurePattern:
    """失败模式"""
    pattern_id: str
    description: str
    principle: str  # 关联的设计原则
    occurrences: List[Dict[str, Any]] = None  # 发生的 iteration 和详情

    # 统计
    occurrence_count: int = 0
    affected_iterations: List[str] = None

    # 建议
    suggested_fix: str = ""
    priority: str = "medium"  # high, medium, low

    def __post_init__(self):
        if self.occurrences is None:
            self.occurrences = []
        if self.affected_iterations is None:
            self.affected_iterations = []

        self.occurrence_count = len(self.occurrences)
        self.affected_iterations = [o.get("iteration", "") for o in self.occurrences]


@dataclass
class CrossIterationAnalysis:
    """跨 iteration 分析结果"""
    patterns: List[FailurePattern] = None
    ratchet_level: int = 0
    improvements_adopted: int = 0
    total_iterations: int = 0

    # 跨 iteration 统计
    repeated_failures: List[str] = None
    new_failures: List[str] = None
    improving_metrics: List[str] = None
    degrading_metrics: List[str] = None

    warnings: List[str] = None
    criticals: List[str] = None

    def __post_init__(self):
        if self.patterns is None:
            self.patterns = []
        if self.repeated_failures is None:
            self.repeated_failures = []
        if self.new_failures is None:
            self.new_failures = []
        if self.improving_metrics is None:
            self.improving_metrics = []
        if self.degrading_metrics is None:
            self.degrading_metrics = []
        if self.warnings is None:
            self.warnings = []
        if self.criticals is None:
            self.criticals = []


class FailurePatternAnalyzer:
    """失败模式分析器"""

    # 预定义的失败模式模板
    KNOWN_PATTERNS = {
        "context_overload": {
            "description": "上下文超载导致 Agent 遗忘早期信息",
            "principle": "context_is_scarce",
            "suggestion": "增加 milestone review 频率，或拆分任务为更小的 sub-task",
            "priority": "high"
        },
        "lint_bypassed": {
            "description": "P0 lint 检查被跳过或失败后继续执行",
            "principle": "verification_mechanism",
            "suggestion": "将 P0 checks 改为不可绕过，或增加强制检查点",
            "priority": "critical"
        },
        "skill_sequence_skipped": {
            "description": "跳过了 skill 链路中的关键步骤",
            "principle": "skill_path_compliance",
            "suggestion": "在 execute-task 中增加前置 skill 完成检查",
            "priority": "high"
        },
        "repeated_same_error": {
            "description": "同一类型的错误反复出现",
            "principle": "self_evolution",
            "suggestion": "将此类错误的检查编码到 lint 或 P0 rules",
            "priority": "high"
        },
        "coordinator_edited_code": {
            "description": "协调者角色直接编辑了代码",
            "principle": "coordinator_not_coder",
            "suggestion": "重构 execute-task，明确协调者和执行者的边界",
            "priority": "critical"
        },
        "missing_pre_verification": {
            "description": "关键操作前缺少前置验证",
            "principle": "forward_verification",
            "suggestion": "在 skill 中增加预验证检查点",
            "priority": "medium"
        },
    }

    def __init__(self, evolution_dir: str):
        self.evolution_dir = evolution_dir
        self.iterations: List[str] = []
        self.iteration_data: Dict[str, Dict[str, Any]] = {}

    def load_iterations(self, iterations: List[str]) -> None:
        """加载多个 iteration 的数据"""
        self.iterations = iterations

        for iter_dir in iterations:
            # 加载 metrics
            metrics_file = os.path.join(iter_dir, "metrics.json")
            if os.path.exists(metrics_file):
                with open(metrics_file, "r") as f:
                    self.iteration_data[iter_dir] = {"metrics": json.load(f)}

            # 加载 scorecard（如果存在）
            scorecard_file = os.path.join(iter_dir, "scorecard.json")
            if os.path.exists(scorecard_file):
                with open(scorecard_file, "r") as f:
                    data = self.iteration_data.get(iter_dir, {})
                    data["scorecard"] = json.load(f)
                    self.iteration_data[iter_dir] = data

    def analyze(self) -> CrossIterationAnalysis:
        """执行跨 iteration 分析"""
        result = CrossIterationAnalysis()
        result.total_iterations = len(self.iterations)

        # 读取进化状态
        state_file = os.path.join(self.evolution_dir, "state.md")
        if os.path.exists(state_file):
            result = self._parse_evolution_state(state_file, result)

        # 分析失败模式
        result.patterns = self._identify_patterns()

        # 检查跨 iteration 趋势
        self._analyze_trends(result)

        # 生成建议
        self._generate_recommendations(result)

        return result

    def _parse_evolution_state(self, state_file: str, result: CrossIterationAnalysis) -> CrossIterationAnalysis:
        """解析进化状态文件"""
        with open(state_file, "r") as f:
            content = f.read()

        # 解析 ratchet level
        import re
        level_match = re.search(r"Level:\s*(\d+)", content)
        if level_match:
            result.ratchet_level = int(level_match.group(1))

        # 统计已采纳的改进
        improvements_dir = os.path.join(self.evolution_dir, "improvements", "adopted")
        if os.path.exists(improvements_dir):
            improvements = os.listdir(improvements_dir)
            result.improvements_adopted = len([f for f in improvements if f.endswith(".md")])

        return result

    def _identify_patterns(self) -> List[FailurePattern]:
        """从数据中识别失败模式"""
        patterns_found = []
        pattern_occurrences = defaultdict(list)

        # 收集所有 iteration 的问题
        for iter_dir, data in self.iteration_data.items():
            iter_name = os.path.basename(iter_dir)

            scorecard = data.get("scorecard", {})
            metrics = data.get("metrics", {})

            # 检查已知模式
            for pattern_id, template in self.KNOWN_PATTERNS.items():
                if self._check_pattern_exists(pattern_id, metrics, scorecard):
                    pattern_occurrences[pattern_id].append({
                        "iteration": iter_name,
                        "data": data
                    })

        # 构建失败模式列表
        for pattern_id, occurrences in pattern_occurrences.items():
            template = self.KNOWN_PATTERNS[pattern_id]
            pattern = FailurePattern(
                pattern_id=pattern_id,
                description=template["description"],
                principle=template["principle"],
                occurrences=occurrences,
                suggested_fix=template["suggestion"],
                priority=template["priority"]
            )
            patterns_found.append(pattern)

        return patterns_found

    def _check_pattern_exists(self, pattern_id: str, metrics: Dict, scorecard: Dict) -> bool:
        """检查指定模式是否存在于当前 iteration"""
        if pattern_id == "context_overload":
            tokens_total = metrics.get("tokens_total", 0)
            tool_calls = scorecard.get("tool_calls_count", 0)
            return tool_calls > 50 or tokens_total > 100000

        elif pattern_id == "lint_bypassed":
            # 检查是否有 lint 相关问题
            findings = scorecard.get("findings", [])
            for f in findings:
                if "lint" in f.lower() or "p0" in f.lower():
                    if "bypass" in f.lower() or "skip" in f.lower() or "fail" in f.lower():
                        return True
            return False

        elif pattern_id == "skill_sequence_skipped":
            findings = scorecard.get("findings", [])
            for f in findings:
                if "skip" in f.lower() or "missing" in f.lower() or "decompose" in f.lower():
                    if "step" in f.lower() or "skill" in f.lower():
                        return True
            return False

        elif pattern_id == "repeated_same_error":
            # 需要跨 iteration 比较，暂时返回 False
            return False

        elif pattern_id == "coordinator_edited_code":
            findings = scorecard.get("findings", [])
            for f in findings:
                if "coordinator" in f.lower() and "edit" in f.lower():
                    return True
            return False

        elif pattern_id == "missing_pre_verification":
            findings = scorecard.get("findings", [])
            for f in findings:
                if "pre-verification" in f.lower() or "前置验证" in f:
                    return True
            return False

        return False

    def _analyze_trends(self, result: CrossIterationAnalysis) -> None:
        """分析跨 iteration 趋势"""
        if len(self.iterations) < 2:
            return

        # 比较相邻 iteration 的指标
        sorted_iters = sorted(self.iteration_data.keys())

        for i in range(1, len(sorted_iters)):
            prev_iter = sorted_iters[i - 1]
            curr_iter = sorted_iters[i]

            prev_metrics = self.iteration_data[prev_iter].get("metrics", {})
            curr_metrics = self.iteration_data[curr_iter].get("metrics", {})

            # 比较 tokens
            prev_tokens = prev_metrics.get("tokens_total", 0)
            curr_tokens = curr_metrics.get("tokens_total", 0)

            if curr_tokens < prev_tokens:
                result.improving_metrics.append(f"tokens_total: {prev_tokens} → {curr_tokens}")
            elif curr_tokens > prev_tokens * 1.2:
                result.degrading_metrics.append(f"tokens_total: {prev_tokens} → {curr_tokens}")

    def _generate_recommendations(self, result: CrossIterationAnalysis) -> None:
        """生成建议"""
        for pattern in result.patterns:
            if pattern.priority == "critical":
                result.criticals.append(
                    f"[{pattern.pattern_id}] {pattern.description} "
                    f"(出现 {pattern.occurrence_count} 次) - {pattern.suggested_fix}"
                )
            elif pattern.priority == "high" and pattern.occurrence_count >= 2:
                result.warnings.append(
                    f"[{pattern.pattern_id}] {pattern.description} "
                    f"(出现 {pattern.occurrence_count} 次)"
                )

        # 检查棘轮效应
        if result.improvements_adopted == 0 and result.total_iterations >= 3:
            result.warnings.append(
                f"连续 {result.total_iterations} 个 iteration 未采纳任何改进，"
                f"棘轮效应未生效"
            )

    def get_summary(self, analysis: CrossIterationAnalysis) -> str:
        """获取分析摘要"""
        lines = [
            "## 跨 Iteration 失败模式分析",
            "",
            f"- 总 Iteration 数: {analysis.total_iterations}",
            f"- Ratchet Level: {analysis.ratchet_level}",
            f"- 已采纳改进: {analysis.improvements_adopted}",
            f"- 发现模式数: {len(analysis.patterns)}",
            "",
        ]

        if analysis.criticals:
            lines.append("### 严重问题 (需立即修复)")
            for c in analysis.criticals:
                lines.append(f"- 🔴 {c}")
            lines.append("")

        if analysis.warnings:
            lines.append("### 警告")
            for w in analysis.warnings:
                lines.append(f"- 🟡 {w}")
            lines.append("")

        if analysis.patterns:
            lines.append("### 失败模式详情")
            for p in analysis.patterns:
                lines.append(f"#### {p.pattern_id}")
                lines.append(f"- 描述: {p.description}")
                lines.append(f"- 出现次数: {p.occurrence_count}")
                lines.append(f"- 影响 iteration: {', '.join(p.affected_iterations)}")
                lines.append(f"- 建议: {p.suggested_fix}")
                lines.append("")

        if analysis.improving_metrics:
            lines.append("### 改善趋势")
            for m in analysis.improving_metrics:
                lines.append(f"- 📈 {m}")
            lines.append("")

        if analysis.degrading_metrics:
            lines.append("### 恶化趋势")
            for m in analysis.degrading_metrics:
                lines.append(f"- 📉 {m}")
            lines.append("")

        if not analysis.criticals and not analysis.warnings:
            lines.append("✅ 未发现系统性失败模式")

        return "\n".join(lines)


def analyze_cross_iterations(evolution_dir: str, iterations: List[str]) -> CrossIterationAnalysis:
    """便捷函数：跨 iteration 分析"""
    analyzer = FailurePatternAnalyzer(evolution_dir)
    analyzer.load_iterations(iterations)
    return analyzer.analyze()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("用法: failure_pattern.py <evolution_dir> <iter1> <iter2> ...")
        sys.exit(1)

    evolution_dir = sys.argv[1]
    iterations = sys.argv[2:]

    analysis = analyze_cross_iterations(evolution_dir, iterations)
    analyzer = FailurePatternAnalyzer(evolution_dir)
    print(analyzer.get_summary(analysis))
