#!/bin/bash
# harness-executor-tester.sh
# Run harness-executor skill tests using top-level Claude Code sessions
# so that sub-agents can spawn their own sub-agents.

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
SKILL_DIR="/Users/josh_folder/harness-simple/skills/harness-executor"
WORKSPACE_ROOT="/Users/josh_folder/harness-simple/skills/harness-executor-workspace"
SOURCE_PROJECT="/Users/josh_folder/hp-sleeper"
MODEL="sonnet"

# ── Args ────────────────────────────────────────────────────────────
ITERATION="${1:?Usage: $0 <iteration> [--with-skill|--without-skill|--both] [--prompt <prompt>] [--bug <bug-script>]}"
SCOPE="${2:---both}"
PROMPT=""
BUG_SCRIPT=""

# Parse extra args
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)    PROMPT="$2"; shift 2 ;;
    --bug)       BUG_SCRIPT="$2"; shift 2 ;;
    --model)     MODEL="$2"; shift 2 ;;
    *)           shift ;;
  esac
done

# Defaults
PROMPT="${PROMPT:-In the project at /Users/josh_folder/hp-sleeper-test-{RUN_ID}/, fix the bug where sleep information cannot be read correctly. When querying sleep history with a date range, the API always returns empty results even though sleep records exist in the database. Save a detailed transcript of everything you did to {OUTPUT_DIR}/transcript.md}"

EVAL_NAME="sleep-reading-bug"
RUN_DIR="${WORKSPACE_ROOT}/iteration-${ITERATION}/eval-${EVAL_NAME}"

echo "══════════════════════════════════════════════════════"
echo "  harness-executor-tester  iteration=${ITERATION}"
echo "  scope=${SCOPE}  model=${MODEL}"
echo "══════════════════════════════════════════════════════"

# ── Setup ───────────────────────────────────────────────────────────
setup_project() {
  local run_id="$1"  # "with_skill" or "without_skill"
  local project_path="/Users/josh_folder/hp-sleeper-test-${run_id}"

  echo "[setup] Resetting project for ${run_id}..."
  rm -rf "${project_path}"
  cp -r "${SOURCE_PROJECT}" "${project_path}"

  # Plant the bug if a bug script is provided
  if [[ -n "${BUG_SCRIPT}" && -f "${BUG_SCRIPT}" ]]; then
    echo "[setup] Planting bug via ${BUG_SCRIPT}..."
    bash "${BUG_SCRIPT}" "${project_path}"
  else
    # Default bug: invert gte/lte in sleepService.ts
    echo "[setup] Planting default bug (gte/lte inversion)..."
    sed -i '' \
      's/if (from) where.date.gte = from/if (from) where.date.lte = from/' \
      "${project_path}/backend/src/services/sleepService.ts"
    sed -i '' \
      's/if (to) where.date.lte = to/if (to) where.date.gte = to/' \
      "${project_path}/backend/src/services/sleepService.ts"
  fi

  echo "[setup] Project ready at ${project_path}"
}

setup_workspace() {
  local run_id="$1"
  mkdir -p "${RUN_DIR}/${run_id}/outputs"
}

# ── Runners ─────────────────────────────────────────────────────────
run_with_skill() {
  local run_id="with_skill"
  local project_path="/Users/josh_folder/hp-sleeper-test-${run_id}"
  local output_dir="${RUN_DIR}/${run_id}/outputs"

  setup_workspace "${run_id}"
  setup_project "${run_id}"

  # Build prompt — inject skill reference and project path
  local task_prompt
  task_prompt=$(echo "${PROMPT}" | sed \
    "s|/Users/josh_folder/hp-sleeper-test-{RUN_ID}|${project_path}|g" \
    | sed "s|{OUTPUT_DIR}|${output_dir}|g")

  local full_prompt="You have access to the harness-executor skill. Read the skill file at ${SKILL_DIR}/SKILL.md first, then follow its workflow exactly to complete this task:

${task_prompt}

SCOPE CONSTRAINT: Only fix the specific bug described above. Do NOT fix other bugs, refactor unrelated code, or make changes outside the sleep query logic. If you find other issues, note them in the trace file but do NOT act on them.

WORKFLOW REMINDERS:
- Step 5 (Execute): You MUST delegate the implementation to a sub-agent using the Agent tool. Do NOT write the fix yourself.
- Step 6 (Validate): Run ALL 5 pipeline steps (build, lint-deps, lint-quality, test, verify). Report each result.
- Step 8 (Complete): Write trace to harness/trace/, memory to harness/memory/INDEX.md, git commit with conventional format.

After completing all steps, write a transcript.md to ${output_dir}/transcript.md summarizing everything you did."

  echo "[with_skill] Starting top-level claude session..."
  local start_time
  start_time=$(date +%s)

  claude -p "${full_prompt}" \
    --model "${MODEL}" \
    --permission-mode bypassPermissions \
    --output-format json \
    --max-budget-usd 10.0 \
    --name "harness-eval-${ITERATION}-with-skill" \
    2>/dev/null > "${output_dir}/claude_output.json" || true

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo "{\"duration_ms\": $(( duration * 1000 )), \"total_duration_seconds\": ${duration}}" \
    > "${RUN_DIR}/${run_id}/timing.json"

  echo "[with_skill] Done in ${duration}s. Output at ${output_dir}/claude_output.json"

  # Extract transcript from JSON output if the agent saved one
  if [[ -f "${output_dir}/transcript.md" ]]; then
    echo "[with_skill] Transcript saved at ${output_dir}/transcript.md"
  fi
}

run_without_skill() {
  local run_id="without_skill"
  local project_path="/Users/josh_folder/hp-sleeper-test-${run_id}"
  local output_dir="${RUN_DIR}/${run_id}/outputs"

  setup_workspace "${run_id}"
  setup_project "${run_id}"

  local task_prompt
  task_prompt=$(echo "${PROMPT}" | sed \
    "s|/Users/josh_folder/hp-sleeper-test-{RUN_ID}|${project_path}|g" \
    | sed "s|{OUTPUT_DIR}|${output_dir}|g")

  local full_prompt="Execute the following development task. Do NOT use any skill files — just use your normal capabilities:

${task_prompt}"

  echo "[without_skill] Starting top-level claude session..."
  local start_time
  start_time=$(date +%s)

  claude -p "${full_prompt}" \
    --model "${MODEL}" \
    --permission-mode bypassPermissions \
    --output-format json \
    --max-budget-usd 10.0 \
    --name "harness-eval-${ITERATION}-without-skill" \
    2>/dev/null > "${output_dir}/claude_output.json" || true

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo "{\"duration_ms\": $(( duration * 1000 )), \"total_duration_seconds\": ${duration}}" \
    > "${RUN_DIR}/${run_id}/timing.json"

  echo "[without_skill] Done in ${duration}s. Output at ${output_dir}/claude_output.json"

  if [[ -f "${output_dir}/transcript.md" ]]; then
    echo "[without_skill] Transcript saved at ${output_dir}/transcript.md"
  fi
}

# ── Main ────────────────────────────────────────────────────────────
case "${SCOPE}" in
  --with-skill)
    run_with_skill
    ;;
  --without-skill)
    run_without_skill
    ;;
  --both)
    echo ""
    echo ">>> Running with_skill first, then without_skill <<<"
    echo ""
    run_with_skill
    echo ""
    run_without_skill
    ;;
  *)
    echo "Unknown scope: ${SCOPE}. Use --with-skill, --without-skill, or --both"
    exit 1
    ;;
esac

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Done! Results at:"
echo "  ${RUN_DIR}/"
echo ""
echo "  Next steps:"
echo "  1. Read transcripts in with_skill/outputs/ and without_skill/outputs/"
echo "  2. Grade each run against assertions"
echo "  3. Generate benchmark.json"
echo "══════════════════════════════════════════════════════"
