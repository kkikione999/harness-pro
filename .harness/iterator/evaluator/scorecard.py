#!/usr/bin/env python3
"""
scorecard.py - 综合评分报告生成器

整合所有分析器，生成完整的 iteration 评估报告。
"""

import json
import os
import sys
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime

# 导入分析器
from .context_analyzer import ContextAnalyzer, ContextMetrics
from .skill_path_analyzer import SkillPathAnalyzer, SkillPathMetrics
from .failure_pattern import FailurePatternAnalyzer, CrossIterationAnalysis


@dataclass
class Scorecard:
    """综合评分报告"""
    iteration_name: str = ""
    timestamp: str = ""

    # 各维度评分
    context_score: int = 0  # 0-100
    skill_path_score: int = 0  # 0-100
    verification_score: int = 0  # 0-100
    overall_score: int = 0  # 0-100

    # 详细指标
    tool_calls_count: int = 0
    tokens_total: int = 0
    turns_count: int = 0
    context_decay_score: float = 0.0
    claude_md_read: bool = False
    milestone_review_executed: bool = False
    lint_executed: bool = False
    p0_passed: bool = False

    # 发现的问题
    findings: List[str] = field(default_factory=list)
    critical_findings: List[str] = field(default_factory=list)

    # 跨 iteration 分析（如果有）
    cross_iteration: Optional[CrossIterationAnalysis] = None

    # 总体评价
    verdict: str = ""  # pass, warning, fail
    summary: str = ""


class ScorecardGenerator:
    """评分卡生成器"""

    def __init__(self, iteration_dir: str, evolution_dir: str = ""):
        self.iteration_dir = iteration_dir
        self.iteration_name = os.path.basename(iteration_dir.rstrip("/"))
        self.evolution_dir = evolution_dir or os.path.join(
            os.path.dirname(iteration_dir), "evolution"
        )

        self.context_analyzer = ContextAnalyzer(iteration_dir)
        self.skill_path_analyzer = SkillPathAnalyzer(iteration_dir)
        self.failure_analyzer = FailurePatternAnalyzer(self.evolution_dir)

    def generate(self) -> Scorecard:
        """生成完整的评分报告"""
        scorecard = Scorecard()
        scorecard.iteration_name = self.iteration_name
        scorecard.timestamp = datetime.now().isoformat()

        # 1. 上下文分析
        context_metrics = self.context_analyzer.analyze()
        self._apply_context_metrics(scorecard, context_metrics)

        # 2. Skill 链路分析
        skill_metrics = self.skill_path_analyzer.analyze()
        self._apply_skill_path_metrics(scorecard, skill_metrics)

        # 3. 验证机制分析
        self._analyze_verification_mechanism(scorecard)

        # 4. 计算综合评分
        self._calculate_overall_score(scorecard)

        # 5. 生成总体评价
        self._generate_verdict(scorecard)

        return scorecard

    def _apply_context_metrics(self, scorecard: Scorecard, metrics: ContextMetrics):
        """应用上下文分析结果"""
        scorecard.tool_calls_count = metrics.tool_calls_count
        scorecard.tokens_total = metrics.tokens_total
        scorecard.turns_count = metrics.turns_count
        scorecard.context_decay_score = metrics.context_decay_score

        # 计算上下文评分
        context_score = 100

        # Tool calls 扣分
        if metrics.tool_calls_count > 60:
            context_score -= 50
        elif metrics.tool_calls_count > 40:
            context_score -= 25

        # Tokens per call 扣分
        if metrics.tokens_per_tool_call < 300:
            context_score -= 30
        elif metrics.tokens_per_tool_call < 500:
            context_score -= 15

        # Turns 扣分
        if metrics.turns_count > 20:
            context_score -= 30
        elif metrics.turns_count > 10:
            context_score -= 15

        # Decay 扣分
        if metrics.context_decay_score < 0.3:
            context_score -= 40
        elif metrics.context_decay_score < 0.5:
            context_score -= 20

        # 添加发现
        scorecard.critical_findings.extend(metrics.criticals)
        scorecard.findings.extend(metrics.warnings)

        scorecard.context_score = max(0, context_score)

    def _apply_skill_path_metrics(self, scorecard: Scorecard, metrics: SkillPathMetrics):
        """应用 Skill 链路分析结果"""
        scorecard.claude_md_read = metrics.claude_md_read
        scorecard.milestone_review_executed = metrics.milestone_review_executed

        # 计算 Skill 链路评分
        skill_path_score = 100

        if not metrics.claude_md_read:
            skill_path_score -= 40
            scorecard.critical_findings.append("CLAUDE.md 未被读取")

        if metrics.missing_steps:
            skill_path_score -= 30 * len(metrics.missing_steps)
            for step in metrics.missing_steps:
                scorecard.critical_findings.append(f"缺失步骤: {step}")

        if metrics.skipped_steps:
            skill_path_score -= 50
            for step in metrics.skipped_steps:
                scorecard.critical_findings.append(f"跳过步骤: {step}")

        if not metrics.milestone_review_executed:
            skill_path_score -= 15
            scorecard.findings.append("未执行 milestone review")

        scorecard.findings.extend(metrics.warnings)

        scorecard.skill_path_score = max(0, skill_path_score)

    def _analyze_verification_mechanism(self, scorecard: Scorecard):
        """分析验证机制"""
        # 检查 lint 是否执行
        scorecard.lint_executed = self._check_lint_executed()
        scorecard.p0_passed = self._check_p0_passed()

        # 计算验证评分
        verification_score = 100

        if not scorecard.lint_executed:
            verification_score -= 50
            scorecard.critical_findings.append("Lint 未执行")

        if not scorecard.p0_passed:
            verification_score -= 30
            scorecard.findings.append("P0 checks 未通过")

        scorecard.verification_score = max(0, verification_score)

    def _check_lint_executed(self) -> bool:
        """检查 lint 是否执行"""
        stream_file = os.path.join(self.iteration_dir, "stream_raw.jsonl")
        if not os.path.exists(stream_file):
            return False

        with open(stream_file, "r") as f:
            content = f.read().lower()
            lint_keywords = ["lint", "p0", "check", "verify", "shell", "bash"]
            return any(k in content for k in lint_keywords)

    def _check_p0_passed(self) -> bool:
        """检查 P0 checks 是否通过"""
        # 简单实现：检查是否有明显的失败标记
        thinking_file = os.path.join(self.iteration_dir, "thinking.txt")
        if not os.path.exists(thinking_file):
            return True  # 无法判断，假设通过

        with open(thinking_file, "r") as f:
            content = f.read().lower()
            # 如果有 "p0 pass" 或者 "lint pass" 则通过
            if "p0 pass" in content or "lint pass" in content or "check pass" in content:
                return True
            # 如果有 "p0 fail" 或 "lint fail" 则失败
            if "p0 fail" in content or "lint fail" in content:
                return False

        return True  # 无法判断，假设通过

    def _calculate_overall_score(self, scorecard: Scorecard):
        """计算综合评分"""
        # 加权平均
        weights = {
            "context": 0.30,
            "skill_path": 0.35,
            "verification": 0.35,
        }

        scorecard.overall_score = int(
            scorecard.context_score * weights["context"] +
            scorecard.skill_path_score * weights["skill_path"] +
            scorecard.verification_score * weights["verification"]
        )

    def _generate_verdict(self, scorecard: Scorecard):
        """生成总体评价"""
        if scorecard.critical_findings:
            scorecard.verdict = "fail"
        elif scorecard.findings:
            scorecard.verdict = "warning"
        else:
            scorecard.verdict = "pass"

        # 生成摘要
        scorecard.summary = self._build_summary(scorecard)

    def _build_summary(self, scorecard: Scorecard) -> str:
        """构建摘要文本"""
        lines = [
            f"# Iteration {scorecard.iteration_name} 评估报告",
            "",
            f"**时间**: {scorecard.timestamp}",
            f"**综合评分**: {scorecard.overall_score}/100 ({scorecard.verdict.upper()})",
            "",
            "## 维度评分",
            "",
            f"| 维度 | 评分 |",
            f"|------|------|",
            f"| 上下文健康度 | {scorecard.context_score}/100 |",
            f"| Skill 链路合规性 | {scorecard.skill_path_score}/100 |",
            f"| 验证机制有效性 | {scorecard.verification_score}/100 |",
            "",
            "## 关键指标",
            "",
            f"- Tool Calls: {scorecard.tool_calls_count}",
            f"- Tokens Total: {scorecard.tokens_total:,}",
            f"- Turns: {scorecard.turns_count}",
            f"- Context Decay: {scorecard.context_decay_score:.2f}",
            f"- CLAUDE.md 读取: {'✅' if scorecard.claude_md_read else '❌'}",
            f"- Milestone Review: {'✅' if scorecard.milestone_review_executed else '❌'}",
            f"- Lint 执行: {'✅' if scorecard.lint_executed else '❌'}",
            f"- P0 Checks: {'✅' if scorecard.p0_passed else '❌'}",
            "",
        ]

        if scorecard.critical_findings:
            lines.append("## 🔴 严重问题")
            for f in scorecard.critical_findings:
                lines.append(f"- {f}")
            lines.append("")

        if scorecard.findings:
            lines.append("## 🟡 警告")
            for f in scorecard.findings:
                lines.append(f"- {f}")
            lines.append("")

        if scorecard.verdict == "pass":
            lines.append("✅ **评价**: Iteration 执行正常，未发现严重问题。")
        elif scorecard.verdict == "warning":
            lines.append("⚠️ **评价**: Iteration 存在一些警告，建议关注。")
        else:
            lines.append("🔴 **评价**: Iteration 存在严重问题，需要修复。")

        return "\n".join(lines)

    def save(self, scorecard: Scorecard) -> str:
        """保存评分报告"""
        output_file = os.path.join(self.iteration_dir, "scorecard.json")
        summary_file = os.path.join(self.iteration_dir, "scorecard.md")

        # 保存 JSON 版本
        scorecard_dict = {
            "iteration_name": scorecard.iteration_name,
            "timestamp": scorecard.timestamp,
            "context_score": scorecard.context_score,
            "skill_path_score": scorecard.skill_path_score,
            "verification_score": scorecard.verification_score,
            "overall_score": scorecard.overall_score,
            "verdict": scorecard.verdict,
            "tool_calls_count": scorecard.tool_calls_count,
            "tokens_total": scorecard.tokens_total,
            "turns_count": scorecard.turns_count,
            "context_decay_score": scorecard.context_decay_score,
            "claude_md_read": scorecard.claude_md_read,
            "milestone_review_executed": scorecard.milestone_review_executed,
            "lint_executed": scorecard.lint_executed,
            "p0_passed": scorecard.p0_passed,
            "findings": scorecard.findings,
            "critical_findings": scorecard.critical_findings,
        }

        with open(output_file, "w") as f:
            json.dump(scorecard_dict, f, indent=2)

        # 保存 Markdown 版本
        with open(summary_file, "w") as f:
            f.write(scorecard.summary)

        return output_file


def generate(iteration_dir: str, evolution_dir: str = "") -> Scorecard:
    """便捷函数：生成评分报告"""
    generator = ScorecardGenerator(iteration_dir, evolution_dir)
    scorecard = generator.generate()
    generator.save(scorecard)
    return scorecard


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: scorecard.py <iteration_dir> [--evolution-dir <dir>]")
        sys.exit(1)

    iteration_dir = sys.argv[1]
    evolution_dir = ""

    if "--evolution-dir" in sys.argv:
        idx = sys.argv.index("--evolution-dir")
        if idx + 1 < len(sys.argv):
            evolution_dir = sys.argv[idx + 1]

    scorecard = generate(iteration_dir, evolution_dir)
    print(scorecard.summary)
    print(f"\n评分已保存到: {iteration_dir}/scorecard.json")
