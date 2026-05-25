#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX_FILE="$SCRIPT_DIR/src/pages/index.astro"

echo "=== Add Project Link ==="
echo ""

read -rp "Project name (display key, e.g. my-repo): " NAME
read -rp "Project URL (e.g. https://github.com/rootHytx/my-repo): " URL

if [[ -z "$NAME" || -z "$URL" ]]; then
  echo "Error: name and URL cannot be empty." >&2
  exit 1
fi

# Check for duplicate
if grep -qF "'$NAME':" "$INDEX_FILE"; then
  echo "Error: '$NAME' already exists in the project list." >&2
  exit 1
fi

# Use Python to insert the new entry before the closing brace of 'github-projects'
python3 - "$INDEX_FILE" "$NAME" "$URL" <<'PYEOF'
import sys

file_path, name, url = sys.argv[1], sys.argv[2], sys.argv[3]

with open(file_path, 'r') as f:
    content = f.read()

new_entry = f"    '{name}': {{ type: 'project', url: '{url}' }},\n"

# Insertion marker: the "},\n  'utilities':" block closes github-projects
marker = "  },\n  'utilities':"
idx = content.find(marker)

if idx == -1:
    print("Error: could not find insertion point in index.astro", file=sys.stderr)
    sys.exit(1)

new_content = content[:idx] + new_entry + content[idx:]

with open(file_path, 'w') as f:
    f.write(new_content)

print(f"Added: '{name}' -> {url}")
PYEOF

echo "Done. Run 'npm run dev' to preview, or push to deploy."
