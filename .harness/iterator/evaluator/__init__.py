"""
evaluator - 迭代器评估器（Critic）

将阿里云 harness 设计的核心理念转化为可观测的指标，
从执行数据中分析问题，识别失败模式。
"""

from .design_principles import (
    DesignPrinciple,
    ObservableMetric,
    PRINCIPLE_METRICS_MAP,
    get_all_metrics,
    get_metrics_for_principle,
    get_principle_by_metric_name,
)

from .context_analyzer import (
    ContextMetrics,
    ContextAnalyzer,
    analyze as analyze_context,
)

from .skill_path_analyzer import (
    SkillPathMetrics,
    SkillPathAnalyzer,
    analyze as analyze_skill_path,
)

from .failure_pattern import (
    FailurePattern,
    CrossIterationAnalysis,
    FailurePatternAnalyzer,
    analyze_cross_iterations,
)

from .scorecard import (
    Scorecard,
    ScorecardGenerator,
    generate as generate_scorecard,
)

__all__ = [
    # design_principles
    "DesignPrinciple",
    "ObservableMetric",
    "PRINCIPLE_METRICS_MAP",
    "get_all_metrics",
    "get_metrics_for_principle",
    "get_principle_by_metric_name",
    # context_analyzer
    "ContextMetrics",
    "ContextAnalyzer",
    "analyze_context",
    # skill_path_analyzer
    "SkillPathMetrics",
    "SkillPathAnalyzer",
    "analyze_skill_path",
    # failure_pattern
    "FailurePattern",
    "CrossIterationAnalysis",
    "FailurePatternAnalyzer",
    "analyze_cross_iterations",
    # scorecard
    "Scorecard",
    "ScorecardGenerator",
    "generate_scorecard",
]
