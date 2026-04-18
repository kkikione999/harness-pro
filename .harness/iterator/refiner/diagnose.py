#!/usr/bin/env python3
"""
diagnose.py - 基于设计原则的诊断器

根据 Critic 的评估结果，基于设计原则生成诊断报告。
"""

import json
import os
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from enum import Enum


class DiagnosticCategory(Enum):
    """诊断类别"""
    CONTEXT_OVERLOAD = "context_overload"
    SKILL_PATH_VIOLATION = "skill_path_violation"
    VERIFICATION_BYPASSED = "verification_bypassed"
    SELF_EVOLUTION_STALLED = "self_evolution_stalled"
    COORDINATOR_CODING = "coordinator_coding"
    FORWARD_VERIFICATION_MISSING = "forward_verification_missing"
    HUMAN_CHECKPOINT_MISALIGNED = "human_checkpoint_misaligned"


@dataclass
class Diagnostic:
    """诊断结果"""
    category: DiagnosticCategory
    severity: str  # critical, high, medium, low
    description: str
    evidence: List[str] = field(default_factory=list)  # 支持证据
    affected_principle: str = ""
    affected_skill: str = ""
    suggested_improvement: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "category": self.category.value,
            "severity": self.severity,
            "description": self.description,
            "evidence": self.evidence,
            "affected_principle": self.affected_principle,
            "affected_skill": self.affected_skill,
            "suggested_improvement": self.suggested_improvement,
        }


class HarnessDiagnoser:
    """Harness 诊断器"""

    # 诊断规则：指标 → 诊断
    DIAGNOSTIC_RULES = {
        # 上下文相关
        ("tool_calls_count", ">", 60): DiagnosticCategory.CONTEXT_OVERLOAD,
        ("context_decay_score", "<", 0.3): DiagnosticCategory.CONTEXT_OVERLOAD,

        # Skill 链路相关
        ("claude_md_read", "==", False): DiagnosticCategory.SKILL_PATH_VIOLATION,
        ("missing_steps", ">", 0): DiagnosticCategory.SKILL_PATH_VIOLATION,
        ("skipped_steps", ">", 0): DiagnosticCategory.SKILL_PATH_VIOLATION,

        # 验证机制相关
        ("lint_executed", "==", False): DiagnosticCategory.VERIFICATION_BYPASSED,
        ("p0_passed", "==", False): DiagnosticCategory.VERIFICATION_BYPASSED,

        # 协调者相关
        ("coordinator_edited_code", "==", True): DiagnosticCategory.COORDINATOR_CODING,
    }

    def __init__(self, iteration_dir: str):
        self.iteration_dir = iteration_dir
        self.scorecard_file = os.path.join(iteration_dir, "scorecard.json")
        self.metrics_file = os.path.join(iteration_dir, "metrics.json")

    def diagnose(self) -> List[Diagnostic]:
        """执行诊断"""
        diagnostics = []

        # 加载数据
        scorecard = self._load_scorecard()
        metrics = self._load_metrics()

        if not scorecard:
            return diagnostics

        # 基于评分卡诊断
        diagnostics.extend(self._diagnose_from_scorecard(scorecard))

        # 基于指标诊断
        diagnostics.extend(self._diagnose_from_metrics(metrics))

        return diagnostics

    def _load_scorecard(self) -> Dict[str, Any]:
        """加载评分卡"""
        if not os.path.exists(self.scorecard_file):
            return {}
        with open(self.scorecard_file, "r") as f:
            return json.load(f)

    def _load_metrics(self) -> Dict[str, Any]:
        """加载指标"""
        if not os.path.exists(self.metrics_file):
            return {}
        with open(self.metrics_file, "r") as f:
            return json.load(f)

    def _diagnose_from_scorecard(self, scorecard: Dict[str, Any]) -> List[Diagnostic]:
        """从评分卡数据诊断"""
        diagnostics = []

        # 检查综合评分
        overall_score = scorecard.get("overall_score", 100)
        if overall_score < 50:
            diag = Diagnostic(
                category=DiagnosticCategory.SELF_EVOLUTION_STALLED,
                severity="high",
                description=f"综合评分过低: {overall_score}/100",
                evidence=[f"Context: {scorecard.get('context_score')}", f"Skill Path: {scorecard.get('skill_path_score')}", f"Verification: {scorecard.get('verification_score')}"],
                affected_principle="overall",
                suggested_improvement="需要进行系统性改进"
            )
            diagnostics.append(diag)

        # 检查上下文评分
        context_score = scorecard.get("context_score", 100)
        if context_score < 60:
            diag = Diagnostic(
                category=DiagnosticCategory.CONTEXT_OVERLOAD,
                severity="critical" if context_score < 40 else "high",
                description=f"上下文健康度不足: {context_score}/100",
                evidence=[f"Tool Calls: {scorecard.get('tool_calls_count')}", f"Tokens: {scorecard.get('tokens_total')}", f"Decay: {scorecard.get('context_decay_score')}"],
                affected_principle="context_is_scarce",
                affected_skill="execute-task",
                suggested_improvement="增加 milestone review 频率，或拆分任务为更小的 sub-task"
            )
            diagnostics.append(diag)

        # 检查 Skill 链路评分
        skill_path_score = scorecard.get("skill_path_score", 100)
        if skill_path_score < 70:
            diag = Diagnostic(
                category=DiagnosticCategory.SKILL_PATH_VIOLATION,
                severity="critical" if skill_path_score < 50 else "high",
                description=f"Skill 链路执行不合规: {skill_path_score}/100",
                evidence=[
                    f"CLAUDE.md read: {scorecard.get('claude_md_read')}",
                    f"Milestone review: {scorecard.get('milestone_review_executed')}",
                ],
                affected_principle="skill_path_compliance",
                affected_skill="execute-task",
                suggested_improvement="确保 decompose → plan → execute → complete 全流程执行"
            )
            diagnostics.append(diag)

        # 检查验证机制评分
        verification_score = scorecard.get("verification_score", 100)
        if verification_score < 70:
            diag = Diagnostic(
                category=DiagnosticCategory.VERIFICATION_BYPASSED,
                severity="critical" if verification_score < 50 else "high",
                description=f"验证机制未有效执行: {verification_score}/100",
                evidence=[
                    f"Lint executed: {scorecard.get('lint_executed')}",
                    f"P0 passed: {scorecard.get('p0_passed')}",
                ],
                affected_principle="verification_mechanism",
                affected_skill="execute-task",
                suggested_improvement="P0 checks 应该是不可绕过的门禁"
            )
            diagnostics.append(diag)

        # 处理 critical findings
        for finding in scorecard.get("critical_findings", []):
            diag = self._classify_finding(finding)
            if diag:
                diagnostics.append(diag)

        return diagnostics

    def _diagnose_from_metrics(self, metrics: Dict[str, Any]) -> List[Diagnostic]:
        """从原始指标诊断"""
        diagnostics = []

        tokens_total = metrics.get("tokens_total", 0)
        if tokens_total > 150000:
            diag = Diagnostic(
                category=DiagnosticCategory.CONTEXT_OVERLOAD,
                severity="high",
                description=f"Token 消耗过高: {tokens_total:,}",
                evidence=[f"Tokens: {tokens_total:,}"],
                affected_principle="context_is_scarce",
                suggested_improvement="考虑拆分任务，减少单次执行的复杂度"
            )
            diagnostics.append(diag)

        return diagnostics

    def _classify_finding(self, finding: str) -> Optional[Diagnostic]:
        """将发现分类为诊断"""
        finding_lower = finding.lower()

        if "context" in finding_lower or "token" in finding_lower or "tool call" in finding_lower:
            return Diagnostic(
                category=DiagnosticCategory.CONTEXT_OVERLOAD,
                severity="high",
                description=finding,
                affected_principle="context_is_scarce",
            )

        if "skip" in finding_lower or "missing" in finding_lower or "decompose" in finding_lower:
            return Diagnostic(
                category=DiagnosticCategory.SKILL_PATH_VIOLATION,
                severity="critical",
                description=finding,
                affected_principle="skill_path_compliance",
            )

        if "lint" in finding_lower or "p0" in finding_lower or "verify" in finding_lower:
            return Diagnostic(
                category=DiagnosticCategory.VERIFICATION_BYPASSED,
                severity="critical",
                description=finding,
                affected_principle="verification_mechanism",
            )

        if "coordinator" in finding_lower and "edit" in finding_lower:
            return Diagnostic(
                category=DiagnosticCategory.COORDINATOR_CODING,
                severity="critical",
                description=finding,
                affected_principle="coordinator_not_coder",
            )

        return None

    def get_summary(self, diagnostics: List[Diagnostic]) -> str:
        """获取诊断摘要"""
        if not diagnostics:
            return "✅ 未发现需要诊断的问题"

        lines = ["## 诊断结果", ""]

        # 按严重性分组
        by_severity = {"critical": [], "high": [], "medium": [], "low": []}
        for d in diagnostics:
            by_severity[d.severity].append(d)

        for severity in ["critical", "high", "medium", "low"]:
            items = by_severity[severity]
            if not items:
                continue

            icon = "🔴" if severity == "critical" else "🟡" if severity == "high" else "🔵"
            lines.append(f"### {icon} {severity.upper()}")
            for item in items:
                lines.append(f"- **{item.category.value}**: {item.description}")
                if item.affected_skill:
                    lines.append(f"  - 影响 Skill: {item.affected_skill}")
                if item.suggested_improvement:
                    lines.append(f"  - 建议: {item.suggested_improvement}")
            lines.append("")

        return "\n".join(lines)


def diagnose(iteration_dir: str) -> List[Diagnostic]:
    """便捷函数：诊断指定 iteration"""
    diagnoser = HarnessDiagnoser(iteration_dir)
    return diagnoser.diagnose()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法: diagnose.py <iteration_dir>")
        sys.exit(1)

    diagnostics = diagnose(sys.argv[1])
    diagnoser = HarnessDiagnoser(sys.argv[1])
    print(diagnoser.get_summary(diagnostics))
