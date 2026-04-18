"""
refiner - 改进生成器（Refiner）

基于 Critic 的诊断，生成具体的 Skill 链路改进提案。
"""

from .diagnose import (
    DiagnosticCategory,
    Diagnostic,
    HarnessDiagnoser,
    diagnose,
)

from .improvement_gen import (
    ImprovementProposal,
    ImprovementGenerator,
    generate as generate_improvements,
)

__all__ = [
    # diagnose
    "DiagnosticCategory",
    "Diagnostic",
    "HarnessDiagnoser",
    "diagnose",
    # improvement_gen
    "ImprovementProposal",
    "ImprovementGenerator",
    "generate_improvements",
]
