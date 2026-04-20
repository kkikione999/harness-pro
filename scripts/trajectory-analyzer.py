#!/usr/bin/env python3
"""
trajectory-analyzer.py
Mechanically analyzes tool call trajectories and generates scripts
when repeated patterns exceed a threshold.

Usage:
    python3 scripts/trajectory-analyzer.py [options]

Options:
    --dir PATH       Trajectory directory (default: harness/trace/trajectories)
    --threshold N    Pattern repetition threshold (default: 3)
    --output DIR     Where to write generated scripts (default: harness/scripts)
    --dry-run        Show patterns without generating scripts
"""

import json
import os
import sys
import hashlib
import re
from collections import defaultdict
from pathlib import Path
from datetime import datetime


# ── Config ──────────────────────────────────────────────────────────

DEFAULT_TRAJ_DIR = "harness/trace/trajectories"
DEFAULT_OUTPUT_DIR = "harness/scripts"
DEFAULT_THRESHOLD = 3

# Tools to track (skip low-value ones like Read)
TRACKED_TOOLS = {
    "Bash", "Edit", "Write", "Agent", "mcp__playwright__browser_click",
    "mcp__chrome-devtools__click", "Skill"
}

# Normalize Bash commands — extract the core command, strip args
BASH_NORMALIZERS = [
    (r'cd\s+\S+\s*&&\s*', ''),           # strip cd prefixes
    (r'npm\s+run\s+(\w+)', r'npm \1'),    # npm run X → npm X
    (r'npm\s+test', 'npm test'),
    (r'npm\s+run\s+build', 'npm build'),
    (r'git\s+(add|commit|push|checkout|stash)\s+.*', r'git \1'),
    (r'git\s+diff\s+.*', 'git diff'),
    (r'git\s+log\s+.*', 'git log'),
    (r'git\s+status.*', 'git status'),
    (r'python3?\s+\S+', 'python SCRIPT'),
    (r'./scripts/\S+', './scripts/SCRIPT'),
    (r'mkdir\s+-p\s+\S+', 'mkdir DIR'),
    (r'cp\s+-r\s+\S+\s+\S+', 'cp SRC DST'),
    (r'rm\s+-rf\s+\S+', 'rm DIR'),
    (r'cat\s+\S+', 'cat FILE'),
    (r'grep\s+.*', 'grep PATTERN'),
    (r'ls\s+.*', 'ls DIR'),
    (r'echo\s+.*', 'echo TEXT'),
    (r'\$HOME[^\s]*', '$PROJECT'),
    (r'/Users/[^\s]+', '$PROJECT'),
]


def load_trajectories(traj_dir: str) -> list[dict]:
    """Load all trajectory JSONL files."""
    trajectories = []
    traj_path = Path(traj_dir)

    if not traj_path.exists():
        print(f"No trajectory directory found at {traj_dir}")
        return trajectories

    for jsonl_file in sorted(traj_path.glob("*.jsonl")):
        session_id = jsonl_file.stem
        with open(jsonl_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entry["_session"] = session_id
                    entry["_file"] = str(jsonl_file)
                    trajectories.append(entry)
                except json.JSONDecodeError:
                    continue

    print(f"Loaded {len(trajectories)} tool calls from {len(list(traj_path.glob('*.jsonl')))} sessions")
    return trajectories


def normalize_step(entry: dict) -> str:
    """Normalize a single tool call into a canonical form for comparison."""
    tool = entry.get("tool", "unknown")

    if tool not in TRACKED_TOOLS:
        return None

    # Support both formats:
    # 1. Logger format: {"tool":"Bash","command":"npm build","file":"..."}
    # 2. Raw hook format: {"tool_name":"Bash","tool_input":{"command":"npm build"}}
    inp = entry.get("input", entry.get("tool_input", {}))

    if tool == "Bash":
        cmd = entry.get("command", inp.get("command", ""))
        if isinstance(cmd, str):
            for pattern, replacement in BASH_NORMALIZERS:
                cmd = re.sub(pattern, replacement, cmd)
            # Take only the first command if chained
            cmd = cmd.split("&&")[0].strip()
            cmd = cmd.split("|")[0].strip()
            return f"Bash: {cmd}"
        return f"Bash: {cmd}"

    if tool == "Edit":
        file_path = inp.get("file_path", "")
        # Normalize path
        file_path = re.sub(r'/Users/[^\s]+', '$PROJECT', file_path)
        file_path = re.sub(r'\$PROJECT/hp-sleeper[A-Za-z0-9_-]*', '$PROJECT', file_path)
        # Just track the filename, not the full path
        filename = os.path.basename(file_path)
        return f"Edit: {filename}"

    if tool == "Write":
        file_path = inp.get("file_path", "")
        file_path = re.sub(r'/Users/[^\s]+', '$PROJECT', file_path)
        filename = os.path.basename(file_path)
        return f"Write: {filename}"

    if tool == "Agent":
        desc = inp.get("description", "agent")
        return f"Agent: {desc}"

    return f"{tool}"


def extract_sequences(trajectories: list[dict], window_sizes: list[int] = None) -> dict[str, list[dict]]:
    """
    Extract normalized tool call sequences of various lengths.
    Returns: pattern_hash → list of occurrences
    """
    if window_sizes is None:
        window_sizes = [3, 4, 5, 6]

    # Group by session
    sessions = defaultdict(list)
    for entry in trajectories:
        sessions[entry["_session"]].append(entry)

    patterns = defaultdict(list)

    for session_id, entries in sessions.items():
        # Build normalized sequence
        steps = []
        for entry in entries:
            norm = normalize_step(entry)
            if norm:
                steps.append({
                    "normalized": norm,
                    "original": entry
                })

        # Extract subsequences of various lengths
        for window_size in window_sizes:
            for i in range(len(steps) - window_size + 1):
                window = steps[i:i + window_size]
                pattern_seq = tuple(s["normalized"] for s in window)
                pattern_hash = hashlib.md5("|".join(pattern_seq).encode()).hexdigest()

                patterns[pattern_hash].append({
                    "pattern": list(pattern_seq),
                    "session": session_id,
                    "start_idx": i,
                    "timestamp": window[0]["original"].get("ts", ""),
                    "originals": [s["original"] for s in window]
                })

    return patterns


def find_repeated_patterns(patterns: dict, threshold: int) -> list[dict]:
    """Find patterns that appear >= threshold times across different sessions."""
    repeated = []

    for pattern_hash, occurrences in patterns.items():
        # Count unique sessions
        unique_sessions = set(o["session"] for o in occurrences)

        if len(unique_sessions) >= threshold:
            pattern = occurrences[0]["pattern"]
            repeated.append({
                "pattern": pattern,
                "count": len(occurrences),
                "sessions": len(unique_sessions),
                "session_ids": list(unique_sessions),
                "occurrences": occurrences,
                "hash": pattern_hash
            })

    # Sort by count descending
    repeated.sort(key=lambda x: x["sessions"], reverse=True)
    return repeated


def deduplicate_patterns(patterns: list[dict]) -> list[dict]:
    """Remove patterns that are substrings of longer patterns."""
    if not patterns:
        return patterns

    # Keep longer patterns, remove their substrings
    result = []
    seen_hashes = set()

    # Sort by pattern length descending (prefer longer patterns)
    patterns.sort(key=lambda x: len(x["pattern"]), reverse=True)

    for p in patterns:
        p_str = "|".join(p["pattern"])
        is_substring = False

        for existing in result:
            e_str = "|".join(existing["pattern"])
            if p_str in e_str and p_str != e_str:
                is_substring = True
                break

        if not is_substring and p["hash"] not in seen_hashes:
            result.append(p)
            seen_hashes.add(p["hash"])

    return result


def generate_script(pattern_info: dict, output_dir: str) -> str:
    """Generate a shell script from a repeated pattern."""
    pattern = pattern_info["pattern"]
    count = pattern_info["sessions"]

    # Generate a descriptive name from the pattern
    name_parts = []
    for step in pattern:
        if step.startswith("Bash:"):
            cmd = step.replace("Bash: ", "").strip()
            # Extract first word as name part
            first_word = cmd.split()[0] if cmd.split() else "cmd"
            name_parts.append(first_word)
        elif step.startswith("Edit:"):
            name_parts.append("edit")
        elif step.startswith("Write:"):
            name_parts.append("write")
        elif step.startswith("Agent:"):
            name_parts.append("delegate")

    script_name = "-".join(name_parts[:4])
    # Clean up
    script_name = re.sub(r'[^a-z0-9-]', '', script_name.lower())

    if not script_name:
        script_name = "pattern"

    script_path = Path(output_dir) / f"auto-{script_name}.sh"

    # Build script content
    lines = [
        "#!/bin/bash",
        f"# Auto-generated trajectory script",
        f"# Pattern detected {count} times across sessions",
        f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"# Pattern: {' → '.join(pattern)}",
        "",
        "set -euo pipefail",
        "",
        'echo "Running auto-detected pattern: {0}"'.format(" → ".join(pattern)),
        "",
    ]

    for step in pattern:
        if step.startswith("Bash:"):
            cmd = step.replace("Bash: ", "")
            lines.append(f"# {step}")
            lines.append(f"echo '> {cmd}'")
            lines.append(f"# {cmd}  # Uncomment to enable")
            lines.append("")
        elif step.startswith("Edit:"):
            filename = step.replace("Edit: ", "")
            lines.append(f"# Edit {filename}")
            lines.append(f"# TODO: Specify the edit")
            lines.append("")
        elif step.startswith("Write:"):
            filename = step.replace("Write: ", "")
            lines.append(f"# Write {filename}")
            lines.append(f"# TODO: Specify the content")
            lines.append("")
        elif step.startswith("Agent:"):
            desc = step.replace("Agent: ", "")
            lines.append(f"# Delegate: {desc}")
            lines.append(f"# TODO: Specify agent task")
            lines.append("")

    lines.append('echo "Pattern complete."')

    # Write script
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    script_path.write_text("\n".join(lines) + "\n")
    os.chmod(script_path, 0o755)

    return str(script_path)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Analyze tool call trajectories")
    parser.add_argument("--dir", default=DEFAULT_TRAJ_DIR, help="Trajectory directory")
    parser.add_argument("--threshold", type=int, default=DEFAULT_THRESHOLD, help="Repetition threshold")
    parser.add_argument("--output", default=DEFAULT_OUTPUT_DIR, help="Output directory for scripts")
    parser.add_argument("--dry-run", action="store_true", help="Show patterns without generating scripts")
    args = parser.parse_args()

    print(f"══ Trajectory Analyzer ══")
    print(f"  Directory:  {args.dir}")
    print(f"  Threshold:  {args.threshold}")
    print(f"  Output:     {args.output}")
    print()

    # Load
    trajectories = load_trajectories(args.dir)
    if not trajectories:
        print("No trajectories found. Run some tasks with the logger hook first.")
        return

    # Extract patterns
    print("\nExtracting patterns...")
    patterns = extract_sequences(trajectories)

    # Find repeated
    repeated = find_repeated_patterns(patterns, args.threshold)
    repeated = deduplicate_patterns(repeated)

    if not repeated:
        print(f"\nNo patterns repeated {args.threshold}+ times yet.")
        print("Keep running tasks — patterns will emerge over time.")
        return

    # Report
    print(f"\n{'═' * 60}")
    print(f"  Found {len(repeated)} repeated pattern(s)")
    print(f"{'═' * 60}")

    for i, p in enumerate(repeated, 1):
        print(f"\n  Pattern #{i} (seen in {p['sessions']} sessions, {p['count']} times)")
        print(f"  {'─' * 50}")
        for j, step in enumerate(p["pattern"], 1):
            print(f"    {j}. {step}")
        print(f"    Sessions: {', '.join(p['session_ids'][:5])}")

    # Generate scripts
    if not args.dry_run:
        print(f"\n{'═' * 60}")
        print(f"  Generating scripts...")
        print(f"{'═' * 60}")

        generated = []
        for p in repeated:
            script_path = generate_script(p, args.output)
            generated.append(script_path)
            print(f"  ✓ {script_path}")

        print(f"\n  Generated {len(generated)} script(s) in {args.output}/")
        print(f"  Review and uncomment commands to activate.")
    else:
        print("\n  [dry-run] No scripts generated. Remove --dry-run to generate.")


if __name__ == "__main__":
    main()
