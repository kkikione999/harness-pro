#!/bin/bash
# Documentation generation script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/generated-docs"

echo "=== harness-blogs Documentation Generation ==="
echo ""

echo "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo ""
echo "--- Generating Documentation Index ---"
index_file="$OUTPUT_DIR/index.html"
cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>harness-blogs Documentation Index</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #333; }
        ul { list-style-type: none; padding: 0; }
        li { margin: 10px 0; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .meta { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>harness-blogs Documentation Index</h1>
    <ul>
EOF

for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f" .md)
        title=$(head -1 "$f" | sed 's/^#* //')
        word_count=$(wc -w < "$f")
        cat >> "$index_file" << EOF
        <li>
            <a href="$filename.html">$filename.md</a>
            <div class="meta">$title | $word_count words</div>
        </li>
EOF
    fi
done

cat >> "$index_file" << 'EOF'
    </ul>
</body>
</html>
EOF

echo "  Generated: index.html"

echo ""
echo "--- Generating Document Summary ---"
summary_file="$OUTPUT_DIR/summary.txt"
echo "harness-blogs Document Summary" > "$summary_file"
echo "Generated: $(date)" >> "$summary_file"
echo "" >> "$summary_file"

total_words=0
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        word_count=$(wc -w < "$f")
        total_words=$((total_words + word_count))
        echo "$filename: $word_count words" >> "$summary_file"
    fi
done

echo "" >> "$summary_file"
echo "Total: $total_words words across $(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ') documents" >> "$summary_file"

echo "  Generated: summary.txt"

echo ""
echo "--- Generating Tags Index ---"
tags_file="$OUTPUT_DIR/tags.txt"
echo "harness-blogs Tags Index" > "$tags_file"
echo "===================" >> "$tags_file"
echo "" >> "$tags_file"

# Extract tags from markdown files
grep -h -oE '#[a-zA-Z0-9_-]+' "$PROJECT_ROOT"/*.md 2>/dev/null | sort | uniq -c | sort -rn >> "$tags_file"

echo "  Generated: tags.txt"

echo ""
echo "=== Documentation Generation Complete ==="
echo "Output directory: $OUTPUT_DIR"