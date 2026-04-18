"""
Harness Iterator - Skill 链路迭代评估工具

基于阿里云 harness 设计的核心理念，对 skill 链路进行迭代评估和改进。

核心模块:
- evaluator: 评估器（Critic）- 将设计原则转化为可观测指标
- refiner: 改进生成器（Refiner）- 基于诊断生成改进提案
- iteration_manager: 迭代管理器 - 管理迭代循环的执行

使用方式:
    # 运行单次迭代
    ./run-evaluation.sh <case_file>

    # 运行多次迭代
    ./run-evaluation.sh <case_file> --iterations 3

    # 跳过改进提案生成
    ./run-evaluation.sh <case_file> --skip-improvements

    # 查看待处理提案
    ./review-improvements.sh list

    # 采纳提案
    ./review-improvements.sh adopt <proposal_id>
"""

__version__ = "0.1.0"
