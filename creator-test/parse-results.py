#!/usr/bin/env python3
"""parse-iterator-results.py - 解析 Claude Code stream-json 输出

增强的错误处理：
1. 处理截断的 JSON 行
2. 从不完整的 stream 中提取尽可能多的数据
3. 标记解析状态（完整/部分/失败）
"""
import json
import sys
import os
import re

def try_parse_json(line):
    """尝试解析 JSON，处理截断情况"""
    line = line.strip()
    if not line:
        return None, "empty line"

    # 尝试直接解析
    try:
        return json.loads(line), None
    except json.JSONDecodeError:
        pass

    # 尝试修复截断的 JSON（常见于 Ctrl+C 中断）
    # 去掉末尾可能的截断内容
    for i in range(len(line), 0, -1):
        try:
            data = json.loads(line[:i])
            # 检查是否是有效的事件
            if isinstance(data, dict) and "type" in data:
                return data, f"truncated (used first {i} chars)"
        except json.JSONDecodeError:
            continue

    return None, "invalid json"


def parse_stream(input_file, output_dir):
    metrics_file = os.path.join(output_dir, "metrics.json")
    thinking_file = os.path.join(output_dir, "thinking.txt")
    tools_file = os.path.join(output_dir, "tool_calls.json")
    output_file = os.path.join(output_dir, "final_output.txt")
    status_file = os.path.join(output_dir, "parse_status.json")

    thinking_chunks = []
    tool_calls = []
    tool_counts = {}
    result_obj = None
    result_text = ""

    # 解析状态
    parse_status = {
        "input_file": input_file,
        "input_size": 0,
        "lines_processed": 0,
        "lines_valid": 0,
        "lines_truncated": 0,
        "lines_error": 0,
        "result_found": False,
        "error": None
    }

    # Handle missing or empty input file
    if not input_file or not os.path.exists(input_file):
        parse_status["error"] = "file not found"
        _write_output_files(thinking_file, tools_file, output_file, metrics_file, status_file,
                          thinking_chunks, tool_calls, tool_counts, result_text, None, parse_status)
        return

    input_size = os.path.getsize(input_file)
    parse_status["input_size"] = input_size

    if input_size == 0:
        parse_status["error"] = "empty file"
        _write_output_files(thinking_file, tools_file, output_file, metrics_file, status_file,
                          thinking_chunks, tool_calls, tool_counts, result_text, None, parse_status)
        return

    try:
        with open(input_file, "r") as f:
            for line in f:
                parse_status["lines_processed"] += 1
                data, issue = try_parse_json(line)

                if data is None:
                    parse_status["lines_error"] += 1
                    if issue and "truncated" in issue:
                        parse_status["lines_truncated"] += 1
                    continue

                parse_status["lines_valid"] += 1
                event_type = data.get("type", "")

                if event_type == "assistant":
                    content = data.get("message", {}).get("content", [])
                    for item in content:
                        if item.get("type") == "thinking":
                            thinking_chunks.append(item.get("thinking", ""))
                        elif item.get("type") == "tool_use":
                            name = item.get("name", "unknown")
                            tool_counts[name] = tool_counts.get(name, 0) + 1
                            tool_calls.append({
                                "name": name,
                                "input": str(item.get("input", {}))[:200]
                            })

                elif event_type == "result" and data.get("subtype") == "success":
                    result_obj = data
                    result_text = data.get("result", "")
                    parse_status["result_found"] = True

    except Exception as e:
        parse_status["error"] = str(e)

    # 如果没有 result 但有 tool_calls，标记为部分完成
    if not parse_status["result_found"] and parse_status["lines_valid"] > 0:
        parse_status["error"] = parse_status.get("error") or "incomplete (no result event)"

    # 添加提取统计到 parse_status
    parse_status["tool_calls_extracted"] = len(tool_calls)
    parse_status["thinking_chunks_extracted"] = len(thinking_chunks)

    _write_output_files(thinking_file, tools_file, output_file, metrics_file, status_file,
                        thinking_chunks, tool_calls, tool_counts, result_text, result_obj, parse_status)


def _write_output_files(thinking_file, tools_file, output_file, metrics_file, status_file,
                        thinking_chunks, tool_calls, tool_counts, result_text, result_obj, parse_status):
    """统一写入所有输出文件"""

    # 写入 thinking
    with open(thinking_file, "w") as f:
        f.write("\n".join(thinking_chunks))

    # 写入 tool_calls
    tools_result = {
        "tool_calls": [{"tool": name, "count": count} for name, count in sorted(tool_counts.items(), key=lambda x: -x[1])],
        "total": len(tool_calls)
    }
    with open(tools_file, "w") as f:
        json.dump(tools_result, f, indent=2)

    # 写入最终输出
    with open(output_file, "w") as f:
        f.write(result_text)

    # 写入 metrics
    if result_obj:
        usage = result_obj.get("usage", {})
        metrics = {
            "duration_ms": result_obj.get("duration_ms", 0),
            "duration_api_ms": result_obj.get("duration_api_ms", 0),
            "total_cost_usd": result_obj.get("total_cost_usd", 0),
            "usage": usage,
            "stop_reason": result_obj.get("stop_reason", ""),
            "terminal_reason": result_obj.get("terminal_reason", ""),
            "num_turns": result_obj.get("num_turns", 0),
            "parse_status": "complete"
        }
        metrics["tokens_total"] = (
            usage.get("input_tokens", 0) +
            usage.get("output_tokens", 0) +
            usage.get("cache_creation_input_tokens", 0) +
            usage.get("cache_read_input_tokens", 0)
        )
        with open(metrics_file, "w") as f:
            json.dump(metrics, f, indent=2)
    else:
        # 部分解析的情况
        with open(metrics_file, "w") as f:
            json.dump({
                "error": parse_status.get("error", "no result found"),
                "parse_status": "partial" if parse_status["lines_valid"] > 0 else "failed"
            }, f, indent=2)

    # 写入解析状态
    with open(status_file, "w") as f:
        json.dump(parse_status, f, indent=2)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: parse-iterator-results.py <stream_file> <output_dir>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_dir = sys.argv[2]

    parse_stream(input_file, output_dir)

    # 输出解析状态
    status_file = os.path.join(output_dir, "parse_status.json")
    if os.path.exists(status_file):
        with open(status_file, "r") as f:
            status = json.load(f)

        if status.get("result_found"):
            print(f"✓ 解析完成（完整）: {status['lines_valid']} 行有效")
        elif status["lines_valid"] > 0:
            print(f"⚠ 解析完成（部分）: {status['lines_valid']}/{status['lines_processed']} 行有效")
            print(f"  提取: {status.get('tool_calls_extracted', 0)} tool calls, {status.get('thinking_chunks_extracted', 0)} thinking chunks")
        else:
            print(f"✗ 解析失败: {status.get('error', 'unknown error')}")

        # 如果有截断行，提示用户
        if status.get("lines_truncated", 0) > 0:
            print(f"  警告: {status['lines_truncated']} 行被截断，已尽力恢复")

    sys.exit(0)