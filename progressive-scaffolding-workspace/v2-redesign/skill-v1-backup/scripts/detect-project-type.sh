#!/bin/bash
# detect-project-type.sh — Identify the project category
# Output: backend | mobile | cli | embedded | desktop
# Also outputs confidence scores for mixed projects

PROJECT_ROOT="${1:-.}"

cd "$PROJECT_ROOT" || exit 1

# Scoring system
declare -A scores
scores[backend]=0
scores[mobile]=0
scores[cli]=0
scores[embedded]=0
scores[desktop]=0

# Backend indicators
if [ -f "package.json" ] && grep -q '"dependencies".*"express"\|"fastify"\|"koa"\|"nest"\|"hapi"' package.json 2>/dev/null; then
    scores[backend]=$((scores[backend] + 3))
fi
if [ -f "go.mod" ] && grep -q "net\/http\|gin\|echo\|fiber" go.mod 2>/dev/null; then
    scores[backend]=$((scores[backend] + 3))
fi
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    if grep -q "flask\|django\|fastapi\|sanic" requirements.txt pyproject.toml 2>/dev/null; then
        scores[backend]=$((scores[backend] + 3))
    fi
fi
if [ -f "docker-compose.yml" ] || [ -f "Dockerfile" ]; then
    scores[backend]=$((scores[backend] + 2))
fi
if [ -f "Makefile" ] && grep -q "run\|serve\|start" Makefile 2>/dev/null; then
    scores[backend]=$((scores[backend] + 1))
fi

# Mobile indicators
if [ -d "android" ] || [ -f "build.gradle" ] || [ -f "settings.gradle" ]; then
    scores[mobile]=$((scores[mobile] + 3))
fi
if [ -d "ios" ] || [ -f "*.xcodeproj" ] || [ -f "*.xcworkspace" ]; then
    scores[mobile]=$((scores[mobile] + 3))
fi
if [ -f "pubspec.yaml" ] && grep -q "flutter" pubspec.yaml 2>/dev/null; then
    scores[mobile]=$((scores[mobile] + 3))
fi
if [ -f "ReactNative" ] || [ -f "App.tsx" ]; then
    scores[mobile]=$((scores[mobile] + 2))
fi

# CLI indicators
if [ -f "package.json" ] && grep -q '"bin"\|"command"' package.json 2>/dev/null; then
    scores[cli]=$((scores[cli] + 3))
fi
if [ -f "Cargo.toml" ] && grep -q "bin\|clap\|structopt" Cargo.toml 2>/dev/null; then
    scores[cli]=$((scores[cli] + 3))
fi
if [ -f "main.go" ] && grep -q "func main()" main.go 2>/dev/null && [ ! -f "go.mod" ]; then
    scores[cli]=$((scores[cli] + 2))
fi
if [ -f "Makefile" ] && grep -q "install\|build\|package" Makefile 2>/dev/null; then
    scores[cli]=$((scores[cli] + 1))
fi

# Embedded indicators
if [ -f "CMakeLists.txt" ] && grep -q "arduino\|esp32\|stm32" CMakeLists.txt 2>/dev/null; then
    scores[embedded]=$((scores[embedded] + 3))
fi
if [ -d "platformio" ] || [ -f "platformio.ini" ]; then
    scores[embedded]=$((scores[embedded] + 3))
fi
if [ -f "*.ino" ] && [ -f "platform.txt" ]; then
    scores[embedded]=$((scores[embedded] + 3))
fi
if [ -f "Makefile" ] && grep -q "cross-compile\|arm\|gcc" Makefile 2>/dev/null; then
    scores[embedded]=$((scores[embedded] + 2))
fi

# Desktop indicators
if [ -f "package.json" ] && grep -q "electron\|nw\|tauri" package.json 2>/dev/null; then
    scores[desktop]=$((scores[desktop] + 3))
fi
if [ -f "Cargo.toml" ] && grep -q "tauri\|egui\|iced\|relm" Cargo.toml 2>/dev/null; then
    scores[desktop]=$((scores[desktop] + 3))
fi
if [ -f "*.ui" ] || [ -f "*.qml" ]; then
    scores[desktop]=$((scores[desktop] + 2))
fi

# Find highest scoring type
max_score=0
max_type="unknown"

for type in "${!scores[@]}"; do
    score=${scores[$type]}
    echo "DEBUG: $type = $score"
    if [ "$score" -gt "$max_score" ]; then
        max_score=$score
        max_type=$type
    fi
done

# If no indicators found, default to cli (simplest case)
if [ "$max_score" -eq 0 ]; then
    max_type="cli"
    max_score=1
fi

# Output result
echo ""
echo "=== Project Type Detection ==="
echo "Type: $max_type"
echo "Confidence: $max_score"
echo ""
echo "All scores:"
for type in backend mobile cli embedded desktop; do
    echo "  $type: ${scores[$type]}"
done

# Exit with type
echo "$max_type"
