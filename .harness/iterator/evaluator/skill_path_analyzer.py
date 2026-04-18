#!/usr/bin/env python3
"""
skill_path_analyzer.py - Skill 链路追踪分析器

分析 Claude 执行过程中的 skill 调用序列，
判断是否符合 harness 设计的 skill 链路要求。
"""

import json
import os
import re
from typing import Dict, List, Any, Optional, Set
from dataclasses import dataclass
from enum import Enum


class SkillStep(Enum):
    """Harness Skill 链路中的关键步骤"""
    DECOMPOSE = "decompose"           # 需求拆解
    CREATE_PLAN = "create_plan"       # 创建计划
    EXECUTE_TASK = "execute_task"    # 执行任务
    COMPLETE_WORK = "complete_work"   # 完成工作
    TDD_RED = "tdd_red"              # TDD 红
    TDD_GREEN = "tdd_green"           # TDD 绿
    TDD_REFACTOR = "tdd_refactor"     # TDD 重构
    MILESTONE_REVIEW = "milestone_review"  # 里程碑审查
    DEBUG = "debug"                  # 调试


@dataclass
class SkillPathMetrics:
    """Skill 链路指标"""
    claude_md_read: bool = False
    skill_sequence: List[str] = None  # 实际执行的 skill 序列
    expected_sequence: List[str] = None  # 期望的 skill 序列
    missing_steps: List[str] = None  # 缺失的步骤
    skipped_steps: List[str] = None  # 跳过的步骤
    repeated_steps: List[str] = None  # 重复的步骤
    milestone_review_executed: bool = False
    review_findings: List[str] = None

    warnings: List[str] = None
    criticals: List[str] = None

    def __post_init__(self):
        if self.skill_sequence is None:
            self.skill_sequence = []
        if self.expected_sequence is None:
            self.expected_sequence = []
        if self.missing_steps is None:
            self.missing_steps = []
        if self.skipped_steps is None:
            self.skipped_steps = []
        if self.repeated_steps is None:
            self.repeated_steps = []
        if self.review_findings is None:
            self.review_findings = []
        if self.warnings is None:
            self.warnings = []
        if self.criticals is None:
            self.criticals = []


class SkillPathAnalyzer:
    """Skill 链路分析器"""

    # Skill 关键词映射：tool call 内容 → Skill 步骤
    SKILL_KEYWORDS = {
        "decompose": ["decompose-requirement", "decompose_requirement", "harness-pro-decompose"],
        "create_plan": ["create-plan", "create_plan", "harness-pro-create-plan"],
        "execute_task": ["execute-task", "execute_task", "harness-pro-execute"],
        "complete_work": ["complete-work", "complete_work", "harness-pro-complete"],
        "tdd": ["test-driven", "tdd", "RED", "GREEN", "REFACTOR"],
        "milestone_review": ["milestone", "review", "milestone_review"],
        "debug": ["debug", "systematic-debugging"],
    }

    # 期望的 skill 链路顺序
    VALID_SEQUENCE = [
        ["decompose", "create_plan", "execute_task", "complete_work"],
        ["decompose", "plan", "execute", "complete"],
    ]

    def __init__(self, iteration_dir: str):
        self.iteration_dir = iteration_dir
        self.stream_file = os.path.join(iteration_dir, "stream_raw.jsonl")
        self.tool_calls_file = os.path.join(iteration_dir, "tool_calls.json")
        self.thinking_file = os.path.join(iteration_dir, "thinking.txt")

    def analyze(self) -> SkillPathMetrics:
        """执行完整的 Skill 链路分析"""
        metrics = SkillPathMetrics()

        # 1. 检查 CLAUDE.md 是否被读取
        metrics.claude_md_read = self._check_claude_md_read()

        # 2. 重建 skill 调用序列
        metrics.skill_sequence = self._rebuild_skill_sequence()

        # 3. 检查里程碑审查是否执行
        metrics.milestone_review_executed = self._check_milestone_review()

        # 4. 检查序列合规性
        self._check_sequence_compliance(metrics)

        # 5. 生成警告
        self._generate_warnings(metrics)

        return metrics

    def _check_claude_md_read(self) -> bool:
        """检查 CLAUDE.md 是否被读取"""
        # 方法1: 检查 stream_raw.jsonl 中是否有读取 CLAUDE.md 的记录
        if os.path.exists(self.stream_file):
            with open(self.stream_file, "r") as f:
                for line in f:
                    if "CLAUDE.md" in line and ("Read" in line or "read" in line):
                        return True

        # 方法2: 检查 thinking.txt
        if os.path.exists(self.thinking_file):
            with open(self.thinking_file, "r") as f:
                content = f.read()
                if "CLAUDE.md" in content or "claude.md" in content:
                    return True

        return False

    def _rebuild_skill_sequence(self) -> List[str]:
        """从 tool_calls 和 thinking 中重建 skill 调用序列"""
        skills_detected = set()

        # 从 thinking 中检测 skill 关键词
        if os.path.exists(self.thinking_file):
            with open(self.thinking_file, "r") as f:
                thinking = f.read().lower()

                for skill_name, keywords in self.SKILL_KEYWORDS.items():
                    for keyword in keywords:
                        if keyword.lower() in thinking:
                            skills_detected.add(skill_name)

        # 从 tool_calls 中检测（如果有结构化数据）
        if os.path.exists(self.tool_calls_file):
            with open(self.tool_calls_file, "r") as f:
                try:
                    data = json.load(f)
                    tool_calls = data.get("tool_calls", [])
                    for call in tool_calls:
                        tool_name = call.get("tool", "").lower()
                        for skill_name, keywords in self.SKILL_KEYWORDS.items():
                            for keyword in keywords:
                                if keyword.lower() in tool_name:
                                    skills_detected.add(skill_name)
                except json.JSONDecodeError:
                    pass

        return list(skills_detected)

    def _check_milestone_review(self) -> bool:
        """检查里程碑审查是否执行"""
        if os.path.exists(self.thinking_file):
            with open(self.thinking_file, "r") as f:
                thinking = f.read().lower()
                review_keywords = ["milestone", "review", "检查点", "checkpoint"]
                for keyword in review_keywords:
                    if keyword in thinking:
                        return True
        return False

    def _check_sequence_compliance(self, metrics: SkillPathMetrics):
        """检查序列是否符合期望"""
        sequence = metrics.skill_sequence

        # 检查是否包含关键 skill
        has_decompose = any(s in sequence for s in ["decompose"])
        has_execute = any(s in sequence for s in ["execute_task", "execute"])
        has_complete = any(s in sequence for s in ["complete_work", "complete"])

        # 基本链路检查
        if not has_decompose:
            metrics.missing_steps.append("decompose (需求拆解)")

        if not has_execute:
            metrics.missing_steps.append("execute (任务执行)")

        if not has_complete:
            metrics.missing_steps.append("complete (完成工作)")

        # 检查是否有不必要的跳过
        # 如果有 execute 但没有 decompose，说明跳过了前置步骤
        if has_execute and not has_decompose:
            metrics.skipped_steps.append("decompose")
            metrics.criticals.append("跳过了 decompose 步骤直接执行任务，流程违规")

        # 检查 milestone review（复杂任务应该有）
        if has_execute and not metrics.milestone_review_executed:
            metrics.warnings.append("复杂任务未执行 milestone review")

    def _generate_warnings(self, metrics: SkillPathMetrics):
        """生成警告信息"""
        if not metrics.claude_md_read:
            metrics.criticals.append("CLAUDE.md 未被读取 - 上下文加载不完整")

        if len(metrics.missing_steps) > 0:
            metrics.criticals.append(
                f"缺失关键步骤: {', '.join(metrics.missing_steps)}"
            )

        if len(metrics.skipped_steps) > 0:
            metrics.criticals.append(
                f"跳过了关键步骤: {', '.join(metrics.skipped_steps)}"
            )

    def get_summary(self, metrics: SkillPathMetrics) -> str:
        """获取分析摘要"""
        lines = [
            "## Skill 链路分析",
            "",
            f"- CLAUDE.md 读取: {'✅' if metrics.claude_md_read else '❌'}",
            f"- 检测到的 Skill: {', '.join(metrics.skill_sequence) if metrics.skill_sequence else '(无)'}",
            f"- Milestone Review: {'✅' if metrics.milestone_review_executed else '❌'}",
            "",
        ]

        if metrics.criticals:
            lines.append("### 严重问题")
            for c in metrics.criticals:
                lines.append(f"- 🔴 {c}")
            lines.append("")

        if metrics.warnings:
            lines.append("### 警告")
            for w in metrics.warnings:
                lines.append(f"- 🟡 {w}")
            lines.append("")

        if metrics.missing_steps:
            lines.append(f"### 缺失步骤")
            for s in metrics.missing_steps:
                lines.append(f"- ❌ {s}")
            lines.append("")

        if not metrics.criticals and not metrics.warnings:
            lines.append("✅ Skill 链路执行正常")

        return "\n".join(lines)


def analyze(iteration_dir: str) -> SkillPathMetrics:
    """便捷函数：分析指定 iteration 目录"""
    analyzer = SkillPathAnalyzer(iteration_dir)
    return analyzer.analyze()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法: skill_path_analyzer.py <iteration_dir>")
        sys.exit(1)

    metrics = analyze(sys.argv[1])
    analyzer = SkillPathAnalyzer(sys.argv[1])
    print(analyzer.get_summary(metrics))
