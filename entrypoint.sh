#!/bin/bash
# Container entrypoint: restore backup -> start NapCat -> start backup loop -> expose dashboard -> start AstrBot
set -u

BACKUP_DIR=/data-git
mkdir -p "$BACKUP_DIR"
git config --global --add safe.directory '*' 2>/dev/null || true

echo "[entrypoint] ===== boot at $(date) ====="

# ---------- 1. Restore data from the private GitHub backup repo ----------
if [ -n "${GITHUB_REPO:-}" ] && [ -n "${GITHUB_PAT:-}" ]; then
  REMOTE="https://x-access-token:${GITHUB_PAT}@github.com/${GITHUB_REPO}.git"
  if [ ! -d "$BACKUP_DIR/.git" ]; then
    echo "[entrypoint] cloning backup repo ${GITHUB_REPO} ..."
    if git clone --depth 1 "$REMOTE" "$BACKUP_DIR" 2>/dev/null; then
      echo "[entrypoint] backup repo cloned."
    else
      echo "[entrypoint] no existing backup found (fresh install) or clone failed."
      rm -rf "$BACKUP_DIR"; mkdir -p "$BACKUP_DIR"
      git init -q "$BACKUP_DIR"
      git -C "$BACKUP_DIR" remote add origin "$REMOTE"
    fi
  else
    git -C "$BACKUP_DIR" pull --rebase --autostash >/dev/null 2>&1 || true
  fi
  if [ -d "$BACKUP_DIR/astrbot" ]; then
    echo "[entrypoint] restoring backed-up data ..."
    mkdir -p /AstrBot/data /app/napcat/config /app/.config/QQ
    rsync -a --delete "$BACKUP_DIR/astrbot/" /AstrBot/data/
    rsync -a "$BACKUP_DIR/napcat-config/" /app/napcat/config/ 2>/dev/null || true
    rsync -a "$BACKUP_DIR/qq/" /app/.config/QQ/ 2>/dev/null || true
    echo "[entrypoint] restore done."
  fi
else
  echo "[entrypoint] WARNING: GITHUB_REPO / GITHUB_PAT not set - persistence disabled!"
fi

# ---------- 2. NapCat <-> AstrBot OneBot link (applied on first init only) ----------
export MODE="${MODE:-reverse_ws}"
export ONEBOT_URL="${ONEBOT_URL:-ws://127.0.0.1:6199/ws}"
export WEBUI_TOKEN="${WEBUI_TOKEN:-render-admin}"
# NapCat's own entrypoint unpacks NapCat, writes onebot11.json/webui.json (first boot only),
# then launches QQ under xvfb. Its output (incl. QR login info) goes to container stdout.
bash /app/entrypoint.sh &
echo "[entrypoint] napcat launched"

# ---------- 3. Periodic backup loop (every 15 min) ----------
( while true; do sleep 900; /usr/local/bin/backup.sh || true; done ) &

# ---------- 4. Expose AstrBot dashboard on Render's $PORT ----------
PORT_NUM="${PORT:-10000}"
socat TCP-LISTEN:"${PORT_NUM}",fork,reuseaddr TCP:127.0.0.1:6185 &
echo "[entrypoint] dashboard proxied 0.0.0.0:${PORT_NUM} -> 127.0.0.1:6185"

# ---------- 5. AstrBot in foreground ----------
cd /AstrBot
exec python main.py
