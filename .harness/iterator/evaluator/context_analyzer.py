#!/usr/bin/env python3
"""
context_analyzer.py - 上下文消耗分析器

分析 Claude 执行过程中的上下文消耗情况，
判断是否存在上下文超载、遗忘等问题。
"""

import json
import os
from typing import Dict, List, Any, Optional
from dataclasses import dataclass


@dataclass
class ContextMetrics:
    """上下文指标"""
    tool_calls_count: int = 0
    tokens_total: int = 0
    tokens_per_tool_call: float = 0.0
    turns_count: int = 0
    duration_ms: int = 0
    thinking_length: int = 0
    early_thinking_density: float = 0.0
    late_thinking_density: float = 0.0
    context_decay_score: float = 1.0

    # 警告和严重标志
    warnings: List[str] = None
    criticals: List[str] = None

    def __post_init__(self):
        if self.warnings is None:
            self.warnings = []
        if self.criticals is None:
            self.criticals = []


class ContextAnalyzer:
    """上下文消耗分析器"""

    def __init__(self, iteration_dir: str):
        self.iteration_dir = iteration_dir
        self.metrics_file = os.path.join(iteration_dir, "metrics.json")
        self.thinking_file = os.path.join(iteration_dir, "thinking.txt")
        self.tool_calls_file = os.path.join(iteration_dir, "tool_calls.json")

    def analyze(self) -> ContextMetrics:
        """执行完整的上下文分析"""
        metrics = self._load_metrics()
        thinking_metrics = self._analyze_thinking()

        # 计算派生指标
        tool_calls_count = self._count_tool_calls()
        tokens_per_tool_call = (
            metrics.get("tokens_total", 0) / tool_calls_count
            if tool_calls_count > 0 else 0
        )

        # 构建结果
        result = ContextMetrics(
            tool_calls_count=tool_calls_count,
            tokens_total=metrics.get("tokens_total", 0),
            tokens_per_tool_call=tokens_per_tool_call,
            turns_count=metrics.get("num_turns", 0),
            duration_ms=metrics.get("duration_ms", 0),
            thinking_length=thinking_metrics.get("total_length", 0),
            early_thinking_density=thinking_metrics.get("early_density", 0),
            late_thinking_density=thinking_metrics.get("late_density", 0),
            context_decay_score=thinking_metrics.get("decay_score", 1.0),
        )

        # 检查阈值并生成警告
        self._check_thresholds(result)

        return result

    def _load_metrics(self) -> Dict[str, Any]:
        """加载 metrics.json"""
        if not os.path.exists(self.metrics_file):
            return {}

        with open(self.metrics_file, "r") as f:
            return json.load(f)

    def _count_tool_calls(self) -> int:
        """统计 tool_calls 数量"""
        if not os.path.exists(self.tool_calls_file):
            return 0

        with open(self.tool_calls_file, "r") as f:
            data = json.load(f)
            return data.get("total", 0)

    def _analyze_thinking(self) -> Dict[str, Any]:
        """分析 thinking 内容的密度变化"""
        if not os.path.exists(self.thinking_file):
            return {
                "total_length": 0,
                "early_density": 0,
                "late_density": 0,
                "decay_score": 1.0
            }

        with open(self.thinking_file, "r") as f:
            thinking = f.read()

        total_length = len(thinking)
        if total_length == 0:
            return {
                "total_length": 0,
                "early_density": 0,
                "late_density": 0,
                "decay_score": 1.0
            }

        # 将 thinking 分成 4 段，计算每段的密度（长度）
        segment_length = total_length // 4
        segments = [
            thinking[0:segment_length],
            thinking[segment_length:segment_length*2],
            thinking[segment_length*2:segment_length*3],
            thinking[segment_length*3:],
        ]

        # 计算早期密度（前两段平均）和晚期密度（后两段平均）
        early_density = (len(segments[0]) + len(segments[1])) / 2
        late_density = (len(segments[2]) + len(segments[3])) / 2

        # 计算衰减分数：晚期密度 / 早期密度（越低说明衰减越严重）
        decay_score = late_density / early_density if early_density > 0 else 0

        return {
            "total_length": total_length,
            "early_density": early_density,
            "late_density": late_density,
            "decay_score": decay_score if decay_score > 0 else 1.0
        }

    def _check_thresholds(self, metrics: ContextMetrics):
        """检查阈值并生成警告"""
        # Tool calls 阈值
        if metrics.tool_calls_count > 60:
            metrics.criticals.append(
                f"上下文严重超载：tool_calls = {metrics.tool_calls_count} > 60"
            )
        elif metrics.tool_calls_count > 40:
            metrics.warnings.append(
                f"上下文可能超载：tool_calls = {metrics.tool_calls_count} > 40"
            )

        # Tokens per tool call 阈值
        if metrics.tokens_per_tool_call < 300:
            metrics.criticals.append(
                f"上下文严重衰减：tokens_per_tool_call = {metrics.tokens_per_tool_call:.1f} < 300"
            )
        elif metrics.tokens_per_tool_call < 500:
            metrics.warnings.append(
                f"上下文可能衰减：tokens_per_tool_call = {metrics.tokens_per_tool_call:.1f} < 500"
            )

        # Turns 阈值
        if metrics.turns_count > 20:
            metrics.criticals.append(
                f"交互轮数过多：turns = {metrics.turns_count} > 20"
            )
        elif metrics.turns_count > 10:
            metrics.warnings.append(
                f"交互轮数偏多：turns = {metrics.turns_count} > 10"
            )

        # Context decay 阈值
        if metrics.context_decay_score < 0.3:
            metrics.criticals.append(
                f"上下文严重遗忘：decay_score = {metrics.context_decay_score:.2f} < 0.3"
            )
        elif metrics.context_decay_score < 0.5:
            metrics.warnings.append(
                f"上下文有所遗忘：decay_score = {metrics.context_decay_score:.2f} < 0.5"
            )

    def get_summary(self, metrics: ContextMetrics) -> str:
        """获取分析摘要"""
        lines = [
            "## 上下文分析",
            "",
            f"- 工具调用次数: {metrics.tool_calls_count}",
            f"- 总 Token 消耗: {metrics.tokens_total:,}",
            f"- 每次调用平均 Token: {metrics.tokens_per_tool_call:.1f}",
            f"- 交互轮数: {metrics.turns_count}",
            f"- Thinking 长度: {metrics.thinking_length:,} chars",
            f"- 上下文衰减分数: {metrics.context_decay_score:.2f}",
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

        if not metrics.criticals and not metrics.warnings:
            lines.append("✅ 上下文消耗正常")

        return "\n".join(lines)


def analyze(iteration_dir: str) -> ContextMetrics:
    """便捷函数：分析指定 iteration 目录"""
    analyzer = ContextAnalyzer(iteration_dir)
    return analyzer.analyze()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法: context_analyzer.py <iteration_dir>")
        sys.exit(1)

    metrics = analyze(sys.argv[1])
    analyzer = ContextAnalyzer(sys.argv[1])
    print(analyzer.get_summary(metrics))
