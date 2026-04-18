#!/usr/bin/env python3
"""
iteration_manager.py - 迭代管理器

管理迭代循环的执行，包括执行、评估、诊断、改进生成。
"""

import json
import os
import subprocess
import sys
import shutil
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass

# 导入评估器和改进生成器
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from evaluator import generate_scorecard
from refiner import generate_improvements, ImprovementProposal


@dataclass
class IterationResult:
    """迭代结果"""
    iteration_name: str
    iteration_dir: str
    execution_success: bool
    evaluation_success: bool
    proposals_generated: int
    scorecard_path: str
    proposals: List[str] = None

    def __post_init__(self):
        if self.proposals is None:
            self.proposals = []


class IterationManager:
    """迭代管理器"""

    def __init__(
        self,
        case_file: str,
        base_output_dir: str = "",
        evolution_dir: str = "",
        iterator_script: str = "",
    ):
        self.case_file = case_file
        self.base_output_dir = base_output_dir or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "output"
        )
        self.evolution_dir = evolution_dir or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "evolution"
        )
        self.iterator_script = iterator_script or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "claude-iterator.sh"
        )

        # 确保目录存在
        os.makedirs(self.base_output_dir, exist_ok=True)
        os.makedirs(self.evolution_dir, exist_ok=True)

        # 初始化棘轮状态
        self._init_evolution_state()

    def _init_evolution_state(self):
        """初始化进化状态文件"""
        state_file = os.path.join(self.evolution_dir, "state.md")
        if not os.path.exists(state_file):
            with open(state_file, "w") as f:
                f.write("# Harness Evolution State\n\n")
                f.write("## Current Ratchet Level\n")
                f.write("Level: 0\n\n")
                f.write("## Evolution History\n\n")
                f.write("*No history yet*\n\n")

    def run_iteration(self, iteration_name: str, skip_improvements: bool = False) -> IterationResult:
        """运行单次迭代"""
        iteration_dir = os.path.join(self.base_output_dir, f"iter_{iteration_name}")
        os.makedirs(iteration_dir, exist_ok=True)

        print(f"\n{'='*60}")
        print(f"迭代 #{iteration_name}")
        print(f"{'='*60}")

        result = IterationResult(
            iteration_name=iteration_name,
            iteration_dir=iteration_dir,
            execution_success=False,
            evaluation_success=False,
            proposals_generated=0,
            scorecard_path="",
        )

        # 1. 执行阶段
        print(f"\n[1/4] 执行阶段...")
        execution_success = self._execute_case(iteration_dir)
        result.execution_success = execution_success

        if not execution_success:
            print("⚠️ 执行阶段有问题，但继续评估...")

        # 2. 评估阶段
        print(f"\n[2/4] 评估阶段...")
        try:
            scorecard = generate_scorecard(iteration_dir, self.evolution_dir)
            result.evaluation_success = True
            result.scorecard_path = os.path.join(iteration_dir, "scorecard.json")
            print(f"✅ 评估完成 - 综合评分: {scorecard.overall_score}/100 ({scorecard.verdict})")
        except Exception as e:
            print(f"❌ 评估失败: {e}")
            result.evaluation_success = False

        # 3. 诊断阶段
        print(f"\n[3/4] 诊断阶段...")
        try:
            from refiner import diagnose
            diagnostics = diagnose(iteration_dir)
            print(f"   发现 {len(diagnostics)} 个诊断问题")
        except Exception as e:
            print(f"⚠️ 诊断失败: {e}")
            diagnostics = []

        # 4. 改进生成阶段
        print(f"\n[4/4] 改进生成阶段...")
        if skip_improvements:
            print("   (跳过 - --skip-improvements 模式)")
        else:
            try:
                proposals = generate_improvements(iteration_dir, self.evolution_dir)
                result.proposals_generated = len(proposals)
                result.proposals = [p.proposal_id for p in proposals]
                print(f"✅ 生成了 {len(proposals)} 个改进提案")
            except Exception as e:
                print(f"⚠️ 改进生成失败: {e}")

        # 更新进化状态
        self._update_evolution_state(result)

        return result

    def _execute_case(self, iteration_dir: str) -> bool:
        """执行 case"""
        # 读取 case 内容
        with open(self.case_file, "r") as f:
            prompt = f.read()

        # 提取 prompt 部分（## Prompt 之后的内容）
        if "## Prompt" in prompt:
            prompt = prompt.split("## Prompt")[1].split("---")[0].strip()

        # 执行 iterator
        try:
            cmd = [
                self.iterator_script,
                prompt,
                iteration_dir
            ]

            print(f"   执行命令: {' '.join(cmd[:2])}...")

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600,  # 10 分钟超时
            )

            if result.returncode != 0:
                print(f"⚠️ Iterator 返回非零: {result.returncode}")
                if result.stderr:
                    print(f"   STDERR: {result.stderr[:500]}")
                return False

            return True

        except subprocess.TimeoutExpired:
            print("❌ 执行超时（10分钟）")
            return False
        except Exception as e:
            print(f"❌ 执行失败: {e}")
            return False

    def _update_evolution_state(self, result: IterationResult):
        """更新进化状态"""
        state_file = os.path.join(self.evolution_dir, "state.md")

        with open(state_file, "r") as f:
            content = f.read()

        # 追加本次迭代信息
        new_entry = f"""
### Iteration {result.iteration_name}
- 时间: {datetime.now().isoformat()}
- 执行: {'✅' if result.execution_success else '❌'}
- 评估: {'✅' if result.evaluation_success else '❌'}
- 评分: {result.scorecard_path}
- 提案: {result.proposals_generated} 个
"""

        # 插入到 Evolution History 之后
        if "## Evolution History" in content:
            parts = content.split("## Evolution History")
            new_content = parts[0] + "## Evolution History\n" + new_entry + "\n".join(parts[1].split("\n")[1:])
        else:
            new_content = content + new_entry

        with open(state_file, "w") as f:
            f.write(new_content)

    def run_multiple(
        self,
        num_iterations: int = 3,
        skip_improvements: bool = False,
    ) -> List[IterationResult]:
        """运行多次迭代"""
        results = []

        for i in range(1, num_iterations + 1):
            iteration_name = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{i}"

            result = self.run_iteration(iteration_name, skip_improvements)
            results.append(result)

            # 如果用户要求跳过改进，则不暂停
            if not skip_improvements and result.proposals_generated > 0:
                print(f"\n📋 生成了 {result.proposals_generated} 个改进提案")
                print("   请查看以下文件进行确认:")
                for proposal_id in result.proposals:
                    print(f"   - {self.evolution_dir}/improvements/pending/{proposal_id}.md")

        return results

    def get_summary(self, results: List[IterationResult]) -> str:
        """获取迭代总结"""
        lines = [
            "# 迭代执行总结",
            "",
            f"**Case**: {os.path.basename(self.case_file)}",
            f"**迭代次数**: {len(results)}",
            "",
            "## 执行结果",
            "",
            "| # | 执行 | 评估 | 评分 | 提案 |",
            "|---|------|------|------|------|",
        ]

        for i, r in enumerate(results, 1):
            score = "N/A"
            if r.scorecard_path and os.path.exists(r.scorecard_path):
                with open(r.scorecard_path, "r") as f:
                    data = json.load(f)
                    score = f"{data.get('overall_score', 'N/A')}/100"

            lines.append(
                f"| {i} | {'✅' if r.execution_success else '❌'} | "
                f"{'✅' if r.evaluation_success else '❌'} | {score} | "
                f"{r.proposals_generated} |"
            )

        lines.append("")

        # 棘轮状态
        state_file = os.path.join(self.evolution_dir, "state.md")
        if os.path.exists(state_file):
            with open(state_file, "r") as f:
                content = f.read()
                if "Level:" in content:
                    import re
                    level_match = re.search(r"Level:\s*(\d+)", content)
                    if level_match:
                        lines.append(f"**当前 Ratchet Level**: {level_match.group(1)}")

        return "\n".join(lines)


def main():
    """主入口"""
    import argparse

    parser = argparse.ArgumentParser(description="Harness Iterator 迭代管理器")
    parser.add_argument("case_file", help="Case 文件路径")
    parser.add_argument(
        "--output-dir",
        default="",
        help="输出目录（默认: .harness/iterator/output）"
    )
    parser.add_argument(
        "--evolution-dir",
        default="",
        help="进化状态目录（默认: .harness/iterator/evolution）"
    )
    parser.add_argument(
        "--iterations", "-n",
        type=int,
        default=1,
        help="迭代次数（默认: 1）"
    )
    parser.add_argument(
        "--skip-improvements",
        action="store_true",
        help="跳过改进生成阶段"
    )

    args = parser.parse_args()

    # 创建管理器
    manager = IterationManager(
        case_file=args.case_file,
        base_output_dir=args.output_dir,
        evolution_dir=args.evolution_dir,
    )

    # 运行迭代
    results = manager.run_multiple(
        num_iterations=args.iterations,
        skip_improvements=args.skip_improvements,
    )

    # 输出总结
    print("\n" + "="*60)
    print(manager.get_summary(results))


if __name__ == "__main__":
    main()
