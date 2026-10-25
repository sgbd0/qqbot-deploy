#!/bin/bash
# Snapshot AstrBot / NapCat / QQ data into the private GitHub backup repo.
set -u

BACKUP_DIR=/data-git
if [ -z "${GITHUB_REPO:-}" ] || [ -z "${GITHUB_PAT:-}" ]; then
  echo "[backup] GITHUB_REPO/GITHUB_PAT not set, skipping"
  exit 0
fi

REMOTE="https://x-access-token:${GITHUB_PAT}@github.com/${GITHUB_REPO}.git"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

if [ ! -d .git ]; then
  git init -q
  git remote add origin "$REMOTE" 2>/dev/null || true
fi
git config user.email "render-bot@users.noreply.github.com"
git config user.name "render-backup"

mkdir -p astrbot napcat-config qq
rsync -a --delete /AstrBot/data/ astrbot/ || echo "[backup] rsync astrbot failed"
rsync -a /app/napcat/config/ napcat-config/ || echo "[backup] rsync napcat failed"
rsync -a /app/.config/QQ/ qq/ || echo "[backup] rsync qq failed"

# keep the repo from growing forever on QQ's cache junk
find qq -type f \( -name '*.tmp' -o -path '*/Crashpad/*' \) -delete 2>/dev/null || true

git add -A
if git diff --cached --quiet; then
  echo "[backup] no changes"
  exit 0
fi

git commit -qm "backup $(date -u '+%Y-%m-%d %H:%M UTC')"
if git push -q -u origin HEAD:main 2>/dev/null || git push -q -u origin main 2>/dev/null || \
   { git branch -M main 2>/dev/null; git push -q -u origin main --force; }; then
  echo "[backup] pushed to ${GITHUB_REPO} at $(date -u '+%H:%M:%S')"
else
  echo "[backup] PUSH FAILED at $(date -u '+%H:%M:%S')"
  exit 1
fi
