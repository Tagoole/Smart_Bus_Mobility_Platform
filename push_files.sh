#!/bin/bash

branch=$(git branch --show-current)

echo "📁 Getting list of all relevant files (excluding .gitignore and tracked ones)..."

files=$(git ls-files --others --modified --exclude-standard)

if [ -z "$files" ]; then
  echo "✅ No uncommitted or untracked files to push."
  exit 0
fi

echo "🔁 Starting commit + push file by file to branch '$branch'..."

for file in $files; do
  if [ ! -f "$file" ]; then
    continue
  fi

  echo "🔧 Adding $file..."
  git add "$file"

  echo "📦 Committing $file..."
  git commit -m "Add or update $file"

  echo "📤 Pushing $file to origin/$branch..."
  git push origin "$branch"

  echo "✅ Done with $file"
  echo "--------------------------"
done

echo "🎉 All files pushed individually!"

