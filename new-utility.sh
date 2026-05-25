#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILITIES_DIR="$SCRIPT_DIR/src/content/utilities"

VALID_CATEGORIES="system docker security networking general nix utility"

echo "=== New Utility Page Generator ==="
echo ""

read -rp "Slug (filename, lowercase, hyphens only — e.g. my-tool): " SLUG

# Sanitize: lowercase, spaces → hyphens, strip anything not a-z0-9-
SLUG=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

if [[ -z "$SLUG" ]]; then
  echo "Error: slug cannot be empty." >&2
  exit 1
fi

FILE="$UTILITIES_DIR/$SLUG.md"
if [[ -f "$FILE" ]]; then
  echo "Error: $FILE already exists." >&2
  exit 1
fi

read -rp "Title: " TITLE
read -rp "Description: " DESCRIPTION

echo "Valid categories: $VALID_CATEGORIES"
read -rp "Category: " CATEGORY

if ! echo "$VALID_CATEGORIES" | grep -qw "$CATEGORY"; then
  echo "Warning: '$CATEGORY' is not a standard category. Proceeding anyway."
fi

read -rp "Tags (comma-separated, e.g. linux,bash,tool): " TAGS_RAW

# Build YAML array from comma-separated tags
TAGS_YAML="["
IFS=',' read -ra TAG_ARR <<< "$TAGS_RAW"
first=true
for tag in "${TAG_ARR[@]}"; do
  tag=$(echo "$tag" | xargs)   # trim whitespace
  [[ -z "$tag" ]] && continue
  $first || TAGS_YAML+=", "
  TAGS_YAML+="\"$tag\""
  first=false
done
TAGS_YAML+="]"

DATE=$(date +%Y-%m-%d)

cat > "$FILE" <<EOF
---
title: "$TITLE"
description: "$DESCRIPTION"
category: "$CATEGORY"
tags: $TAGS_YAML
created: $DATE
---

# $TITLE

$DESCRIPTION

## Overview

<!-- Describe what this utility does and when to use it -->

## Usage

\`\`\`bash
# Add your main command(s) here
\`\`\`

## Examples

\`\`\`bash
# Practical example 1
# ...

# Practical example 2
# ...
\`\`\`

## Notes

- Add important notes, warnings, or tips here
EOF

echo ""
echo "Created: $FILE"
echo "Edit the file to fill in your content, then run 'npm run dev' to preview."
