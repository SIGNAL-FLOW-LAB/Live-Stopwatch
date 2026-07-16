#!/bin/zsh
set -e
cd "$(dirname "$0")"

if [ -d ".git" ]; then
  echo "Git repository already exists."
  exit 0
fi

git init
git add .
git commit -m "Initial release v1.0"

echo "Git repository created."
