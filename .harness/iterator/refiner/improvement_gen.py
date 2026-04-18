#!/usr/bin/env python3
"""
improvement_gen.py - 改进提案生成器

基于诊断结果，生成具体的 Skill 链路改进提案。
"""

import json
import os
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
from .diagnose import Diagnostic, DiagnosticCategory, HarnessDiagnoser


@dataclass
class ImprovementProposal:
    """改进提案"""
    proposal_id: str = ""
    iteration: str = ""
    timestamp: str = ""

    # 来源
    diagnostics: List[str] = field(default_factory=list)  # 来源的诊断描述

    # 提案内容
    affected_skill: str = ""
    improvement_type: str = ""  # prompt_tweak, add_checkpoint, add_rule, restructure, etc.
    description: str = ""
    current_issue: str = ""
    proposed_change: str = ""
    expected_outcome: str = ""

    # 风险评估
    risk_level: str = "medium"  # low, medium, high
    risk_description: str = ""
    rollback_plan: str = ""

    # 验证方式
    verification_method: str = ""
    test_case_suggestion: str = ""

    # 状态
    status: str = "pending"  # pending, adopted, rejected

    def to_dict(self) -> Dict[str, Any]:
        return {
            "proposal_id": self.proposal_id,
            "iteration": self.iteration,
            "timestamp": self.timestamp,
            "diagnostics": self.diagnostics,
            "affected_skill": self.affected_skill,
            "improvement_type": self.improvement_type,
            "description": self.description,
            "current_issue": self.current_issue,
            "proposed_change": self.proposed_change,
            "expected_outcome": self.expected_outcome,
            "risk_level": self.risk_level,
            "risk_description": self.risk_description,
            "rollback_plan": self.rollback_plan,
            "verification_method": self.verification_method,
            "test_case_suggestion": self.test_case_suggestion,
            "status": self.status,
        }

    def to_markdown(self) -> str:
        """转换为 Markdown 格式"""
        lines = [
            f"# 改进提案 #{self.proposal_id}",
            "",
            f"**Iteration**: {self.iteration}",
            f"**时间**: {self.timestamp}",
            f"**状态**: {self.status}",
            f"**影响 Skill**: {self.affected_skill}",
            f"**类型**: {self.improvement_type}",
            "",
            "## 诊断来源",
            "",
        ]

        for d in self.diagnostics:
            lines.append(f"- {d}")

        lines.extend([
            "",
            "## 问题描述",
            "",
            self.current_issue,
            "",
            "## 改进方案",
            "",
            self.proposed_change,
            "",
            "## 预期效果",
            "",
            self.expected_outcome,
            "",
            "## 风险评估",
            "",
            f"**风险等级**: {self.risk_level}",
            f"**风险说明**: {self.risk_description}",
            f"**回滚计划**: {self.rollback_plan}",
            "",
            "## 验证方式",
            "",
            f"**验证方法**: {self.verification_method}",
            f"**建议测试**: {self.test_case_suggestion}",
            "",
        ])

        return "\n".join(lines)


class ImprovementGenerator:
    """改进提案生成器"""

    # 诊断 → 改进 的映射规则
    DIAGNOSTIC_IMPROVEMENT_MAP = {
        DiagnosticCategory.CONTEXT_OVERLOAD: {
            "types": ["prompt_tweak", "add_checkpoint", "restructure"],
            "skills": ["execute-task"],
            "template": {
                "description": "上下文超载改进",
                "improvement_type": "prompt_tweak",
                "risk_level": "medium",
                "risk_description": "修改 prompt 可能影响其他场景",
                "rollback_plan": "保留原 prompt 内容，可快速回滚",
            }
        },
        DiagnosticCategory.SKILL_PATH_VIOLATION: {
            "types": ["add_checkpoint", "prompt_tweak"],
            "skills": ["execute-task", "decompose-requirement"],
            "template": {
                "description": "Skill 链路违规改进",
                "improvement_type": "add_checkpoint",
                "risk_level": "low",
                "risk_description": "增加检查点不影响现有逻辑",
                "rollback_plan": "删除检查点代码即可",
            }
        },
        DiagnosticCategory.VERIFICATION_BYPASSED: {
            "types": ["add_rule", "make_blocking"],
            "skills": ["execute-task"],
            "template": {
                "description": "验证机制绕过改进",
                "improvement_type": "add_rule",
                "risk_level": "high",
                "risk_description": "使验证不可绕过可能阻塞正常流程",
                "rollback_plan": "添加 --skip-verification 参数",
            }
        },
        DiagnosticCategory.SELF_EVOLUTION_STALLED: {
            "types": ["add_rule", "improve_feedback"],
            "skills": ["iterate"],
            "template": {
                "description": "自我进化停滞改进",
                "improvement_type": "add_rule",
                "risk_level": "medium",
                "risk_description": "新增规则可能需要更多测试",
                "rollback_plan": "删除新规则",
            }
        },
        DiagnosticCategory.COORDINATOR_CODING: {
            "types": ["restructure", "prompt_tweak"],
            "skills": ["execute-task"],
            "template": {
                "description": "协调者角色混淆改进",
                "improvement_type": "restructure",
                "risk_level": "high",
                "risk_description": "重构可能影响执行效率",
                "rollback_plan": "保留原有逻辑，增加条件分支",
            }
        },
        DiagnosticCategory.FORWARD_VERIFICATION_MISSING: {
            "types": ["add_checkpoint", "prompt_tweak"],
            "skills": ["execute-task"],
            "template": {
                "description": "前置验证缺失改进",
                "improvement_type": "add_checkpoint",
                "risk_level": "low",
                "risk_description": "增加验证点不影响性能",
                "rollback_plan": "删除验证点代码即可",
            }
        },
    }

    def __init__(self, iteration_dir: str, evolution_dir: str):
        self.iteration_dir = iteration_dir
        self.iteration_name = os.path.basename(iteration_dir.rstrip("/"))
        self.evolution_dir = evolution_dir
        self.proposals_dir = os.path.join(evolution_dir, "improvements", "pending")
        self.diagnoser = HarnessDiagnoser(iteration_dir)

        # 确保目录存在
        os.makedirs(self.proposals_dir, exist_ok=True)

    def generate(self) -> List[ImprovementProposal]:
        """基于诊断生成改进提案"""
        diagnostics = self.diagnoser.diagnose()

        if not diagnostics:
            return []

        proposals = []

        # 为每个诊断生成提案
        for i, diag in enumerate(diagnostics):
            proposal = self._create_proposal(diag, i)
            if proposal:
                proposals.append(proposal)

        # 保存提案
        for proposal in proposals:
            self._save_proposal(proposal)

        return proposals

    def _create_proposal(self, diag: Diagnostic, index: int) -> Optional[ImprovementProposal]:
        """为诊断创建提案"""
        template_config = self.DIAGNOSTIC_IMPROVEMENT_MAP.get(diag.category)

        if not template_config:
            return None

        # template_config has structure: {"types": [...], "skills": [...], "template": {...}}
        template = template_config["template"]

        proposal = ImprovementProposal(
            proposal_id=f"{self.iteration_name}-{diag.category.value}-{index}",
            iteration=self.iteration_name,
            timestamp=datetime.now().isoformat(),
            diagnostics=[diag.description],
            affected_skill=diag.affected_skill or template_config["skills"][0],
            improvement_type=template.get("improvement_type", "unknown"),
            description=template.get("description", ""),
            current_issue=diag.description,
            proposed_change=self._generate_proposed_change(diag, template),
            expected_outcome=diag.suggested_improvement or self._default_expected_outcome(diag),
            risk_level=template.get("risk_level", "medium"),
            risk_description=template.get("risk_description", ""),
            rollback_plan=template.get("rollback_plan", ""),
            verification_method=self._default_verification_method(diag),
            test_case_suggestion=self._default_test_case(diag),
            status="pending",
        )

        return proposal

    def _generate_proposed_change(self, diag: Diagnostic, template: Dict) -> str:
        """生成具体的改进变更描述"""
        category = diag.category

        if category == DiagnosticCategory.CONTEXT_OVERLOAD:
            return """在 execute-task 的 SKILL.md 中增加以下内容：

### 上下文保护措施

当 tool_calls 超过 30 次时：
1. 暂停执行，输出当前进度摘要
2. 评估是否需要拆分为 sub-task
3. 如果需要，继续执行；如果不需要，注明原因后继续

增加 milestone review 的触发频率：
- 每完成一个 milestone 必须 review
- review 时检查上下文消耗，如果消耗过大则拆分后续任务"""

        elif category == DiagnosticCategory.SKILL_PATH_VIOLATION:
            return """在 execute-task 的 SKILL.md 中增加以下前置检查：

### 前置 Skill 检查

在开始执行前：
1. 检查 CLAUDE.md 是否存在，如不存在则停止并提示用户先运行 decompose
2. 检查是否已完成 decompose 步骤（通过检查 docs/features/ 目录）
3. 检查是否已完成 plan 步骤（通过检查 plan.md 是否存在）
4. 如果任何前置步骤缺失，停止执行并输出缺失步骤"""

        elif category == DiagnosticCategory.VERIFICATION_BYPASSED:
            return """在 execute-task 的 SKILL.md 中将 P0 checks 改为不可绕过：

### P0 验证门禁（不可绕过）

在每个 milestone boundary 必须运行 P0 checks：
1. 如果 P0 checks 失败，**必须**修复后才能继续
2. 不允许使用 --skip-p0 或类似参数
3. 如果认为 P0 规则有问题，应在修复后通过迭代器反馈，而不是绕过
4. 紧急情况需要用户提供 --emergency-override 并记录原因"""

        elif category == DiagnosticCategory.COORDINATOR_CODING:
            return """在 execute-task 的 SKILL.md 中明确协调者职责边界：

### 协调者行为准则

**允许协调者做的**：
- 读取和分析代码
- 生成执行计划
- 调用子代理（spawn）
- 验证输出

**禁止协调者做的**：
- 直接使用 Edit/Write 工具修改代码
- 直接运行 bash/shell 命令（验证命令除外）
- 编写业务逻辑代码

**如果需要修改代码**：
必须通过 spawn 一个执行者子代理来完成，传递精确的修改指令"""

        elif category == DiagnosticCategory.FORWARD_VERIFICATION_MISSING:
            return """在 execute-task 的 SKILL.md 中增加前置验证检查：

### 前置验证时机

在以下操作前必须进行合法性验证：
1. **创建新文件** → 验证路径是否符合架构
2. **添加跨包 import** → 验证是否符合依赖规则
3. **修改配置文件** → 验证修改是否安全

验证命令格式：
```bash
# 新文件位置验证
python3 scripts/lint-deps.py --check-path <path>

# 跨包 import 验证
python3 scripts/lint-deps.py --check-import <from_pkg> <to_pkg>
```"""

        else:
            return """需要进一步分析以确定具体的改进方案。"""

    def _default_expected_outcome(self, diag: Diagnostic) -> str:
        """默认的预期结果"""
        return f"解决 {diag.category.value} 问题，提升 Skill 链路的质量和可靠性。"

    def _default_verification_method(self, diag: Diagnostic) -> str:
        """默认的验证方法"""
        return f"在下一次迭代中观察是否仍有 {diag.category.value} 类型的诊断。"

    def _default_test_case(self, diag: Diagnostic) -> str:
        """默认的测试建议"""
        return f"使用与本次迭代相似的 case，观察改进是否生效。"

    def _save_proposal(self, proposal: ImprovementProposal) -> str:
        """保存提案到文件"""
        filename = f"{proposal.proposal_id}.md"
        filepath = os.path.join(self.proposals_dir, filename)

        with open(filepath, "w") as f:
            f.write(proposal.to_markdown())

        return filepath


def generate(iteration_dir: str, evolution_dir: str) -> List[ImprovementProposal]:
    """便捷函数：生成改进提案"""
    generator = ImprovementGenerator(iteration_dir, evolution_dir)
    return generator.generate()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("用法: improvement_gen.py <iteration_dir> <evolution_dir>")
        sys.exit(1)

    proposals = generate(sys.argv[1], sys.argv[2])

    if not proposals:
        print("✅ 未生成改进提案（无诊断问题）")
    else:
        print(f"✅ 生成了 {len(proposals)} 个改进提案:")
        for p in proposals:
            print(f"  - {p.proposal_id}: {p.description}")
