#!/usr/bin/env python3
"""
design_principles.py - 设计原则到可观测指标的映射

这是迭代器的核心定义文件。将阿里云 harness 设计的核心理念
转化为可观测、可测量的指标。
"""

from dataclasses import dataclass
from typing import List, Dict, Callable, Any
from enum import Enum


class DesignPrinciple(Enum):
    """阿里云 harness 设计的核心原则"""
    CONTEXT_IS_SCARCE = "context_is_scarce"           # 上下文是最贵资源
    SKILL_PATH_COMPLIANCE = "skill_path_compliance"   # Skill 链路合规性
    VERIFICATION_MECHANISM = "verification_mechanism" # 验证机制有效性
    SELF_EVOLUTION = "self_evolution"                 # 自我进化能力
    COORDINATOR_NOT_CODER = "coordinator_not_coder"   # 协调者不写代码
    FORWARD_VERIFICATION = "forward_verification"      # 前置验证优先
    HUMAN_CHECKPOINT = "human_checkpoint"              # 人类参与点正确
    RATCHET_EFFECT = "ratchet_effect"                 # 棘轮效应


@dataclass
class ObservableMetric:
    """可观测指标定义"""
    name: str
    description: str
    extraction_method: str  # 如何从数据中提取
    threshold_rules: Dict[str, Any]  # 判断规则


# 设计原则 → 可观测指标的映射
PRINCIPLE_METRICS_MAP: Dict[DesignPrinciple, List[ObservableMetric]] = {
    DesignPrinciple.CONTEXT_IS_SCARCE: [
        ObservableMetric(
            name="tool_calls_count",
            description="总工具调用次数",
            extraction_method="count from tool_calls.json",
            threshold_rules={
                "warning": 40,
                "critical": 60,
                "rule": "tool_calls > 60 → 上下文严重超载"
            }
        ),
        ObservableMetric(
            name="tokens_per_tool_call",
            description="每次工具调用平均消耗 tokens",
            extraction_method="tokens_total / tool_calls_count",
            threshold_rules={
                "warning": 500,
                "critical": 300,
                "rule": "tokens_per_tool_call 持续下降 → Agent 可能丢失上下文"
            }
        ),
        ObservableMetric(
            name="turns_count",
            description="交互轮数",
            extraction_method="from metrics.json num_turns",
            threshold_rules={
                "warning": 10,
                "critical": 20,
                "rule": "turns > 20 → 上下文可能严重超载"
            }
        ),
        ObservableMetric(
            name="context_decay_score",
            description="上下文衰减分数（早期 vs 后期信息密度比）",
            extraction_method="analyze thinking.txt segment density",
            threshold_rules={
                "warning": 0.5,
                "critical": 0.3,
                "rule": "decay_score < 0.3 → Agent 明显遗忘早期信息"
            }
        ),
    ],

    DesignPrinciple.SKILL_PATH_COMPLIANCE: [
        ObservableMetric(
            name="claude_md_read",
            description="CLAUDE.md 是否被读取",
            extraction_method="grep tool_calls for Read CLAUDE.md",
            threshold_rules={
                "required": True,
                "rule": "CLAUDE.md 未被读取 → 上下文加载不完整"
            }
        ),
        ObservableMetric(
            name="skill_path_sequence",
            description="Skill 链路是否按正确顺序执行",
            extraction_method="analyze tool_calls for skill invocations",
            threshold_rules={
                "valid_sequence": ["decompose", "plan", "execute", "complete"],
                "rule": "跳过关键步骤或顺序错误 → 流程违规"
            }
        ),
        ObservableMetric(
            name="milestone_review_executed",
            description="Milestone review 是否执行",
            extraction_method="grep tool_calls for review/verify",
            threshold_rules={
                "required_for_complex": True,
                "rule": "复杂任务未做 milestone review → 缺少质量检查"
            }
        ),
    ],

    DesignPrinciple.VERIFICATION_MECHANISM: [
        ObservableMetric(
            name="lint_executed",
            description="Lint 是否运行",
            extraction_method="grep tool_calls for lint/p0",
            threshold_rules={
                "required": True,
                "rule": "Lint 未运行 → 验证机制未触发"
            }
        ),
        ObservableMetric(
            name="p0_checks_passed",
            description="P0 checks 是否通过",
            extraction_method="analyze tool output for p0 results",
            threshold_rules={
                "required": True,
                "blocking": True,
                "rule": "P0 失败但继续执行 → 验证机制被绕过"
            }
        ),
        ObservableMetric(
            name="verify_executed",
            description="Verify 阶段是否执行",
            extraction_method="grep tool_calls for verify",
            threshold_rules={
                "required_for_end": True,
                "rule": "任务结束前未 verify → 功能正确性未确认"
            }
        ),
    ],

    DesignPrinciple.SELF_EVOLUTION: [
        ObservableMetric(
            name="repeated_failure_pattern",
            description="同一类问题是否反复出现",
            extraction_method="cross-iteration pattern analysis",
            threshold_rules={
                "threshold": 3,
                "rule": "同一错误出现 3+ 次 → 需要编码到 lint/rules"
            }
        ),
        ObservableMetric(
            name="knowledge_solidification",
            description="软知识是否被固化为硬规则",
            extraction_method="check if recurring issues now in lint",
            threshold_rules={
                "ideal": True,
                "rule": "反复出现的问题应该被编码成 lint 规则"
            }
        ),
    ],

    DesignPrinciple.COORDINATOR_NOT_CODER: [
        ObservableMetric(
            name="coordinator_edits_code",
            description="协调者是否直接编辑代码",
            extraction_method="analyze tool_calls for Edit/Write by coordinator",
            threshold_rules={
                "forbidden": True,
                "rule": "协调者使用 Edit/Write → 违反核心原则，应立即停止"
            }
        ),
        ObservableMetric(
            name="task_delegation_rate",
            description="任务委托率",
            extraction_method="subagent/spawn ratio",
            threshold_rules={
                "ideal_min": 0.3,
                "rule": "委托率 < 30% → 协调者可能过于亲力亲为"
            }
        ),
    ],

    DesignPrinciple.FORWARD_VERIFICATION: [
        ObservableMetric(
            name="pre_verification_count",
            description="前置验证次数",
            extraction_method="count verify-before-action patterns",
            threshold_rules={
                "ideal_min": 1,
                "rule": "涉及新文件/跨包 import 时应有前置验证"
            }
        ),
        ObservableMetric(
            name="post_fix_loops",
            description="修复循环次数",
            extraction_method="count edit-then-error patterns",
            threshold_rules={
                "warning": 3,
                "critical": 5,
                "rule": "修复循环 > 5 → 前置验证缺失，应在写代码前验证"
            }
        ),
    ],

    DesignPrinciple.HUMAN_CHECKPOINT: [
        ObservableMetric(
            name="unnecessary_handoffs",
            description="不必要的移交次数",
            extraction_method="analyze handoff patterns",
            threshold_rules={
                "warning": 2,
                "rule": "简单任务被移交 → 人类参与点过于频繁"
            }
        ),
        ObservableMetric(
            name="missed_handoffs",
            description="应该移交但没移交的次数",
            extraction_method="analyze error context for missed checkpoints",
            threshold_rules={
                "warning": 1,
                "rule": "重大偏差未回传用户 → 人类参与点过于稀少"
            }
        ),
    ],

    DesignPrinciple.RATCHET_EFFECT: [
        ObservableMetric(
            name="ratchet_level",
            description="当前棘轮等级",
            extraction_method="read from evolution/state.md",
            threshold_rules={
                "ideal": "只升不降",
                "rule": "每次成功改进应提高 ratchet level"
            }
        ),
        ObservableMetric(
            name="improvements_adopted",
            description="已采纳的改进数量",
            extraction_method="count from evolution/improvements/adopted/",
            threshold_rules={
                "ideal": "持续增长",
                "rule": "停滞说明迭代器未有效改进 skill 链路"
            }
        ),
    ],
}


def get_all_metrics() -> List[ObservableMetric]:
    """获取所有可观测指标"""
    all_metrics = []
    for principle, metrics in PRINCIPLE_METRICS_MAP.items():
        all_metrics.extend(metrics)
    return all_metrics


def get_metrics_for_principle(principle: DesignPrinciple) -> List[ObservableMetric]:
    """获取指定原则的所有指标"""
    return PRINCIPLE_METRICS_MAP.get(principle, [])


def get_principle_by_metric_name(metric_name: str) -> DesignPrinciple:
    """通过指标名反向查找原则"""
    for principle, metrics in PRINCIPLE_METRICS_MAP.items():
        for metric in metrics:
            if metric.name == metric_name:
                return principle
    return None
