#!/bin/sh
# pmcu standard installer — Linux / WSL2. No toolchain needed.
# Usage: curl -fsSL https://raw.githubusercontent.com/tayaee/poor-mans-computer-use/main/install.sh | sh
set -eu
REPO="tayaee/poor-mans-computer-use"
BASE="https://github.com/${REPO}/releases/latest/download"
BIN_DIR="${HOME}/.local/bin"
SKILL_DIR="${HOME}/.claude/skills/pmcu"

mkdir -p "${BIN_DIR}" "${SKILL_DIR}"
echo "[pmcu] downloading binary..."
curl -fsSL "${BASE}/pmcu-linux" -o "${BIN_DIR}/pmcu"
chmod +x "${BIN_DIR}/pmcu"
echo "[pmcu] downloading skill..."
curl -fsSL "${BASE}/pmcu-skill.zip" -o /tmp/pmcu-skill.zip
unzip -oq /tmp/pmcu-skill.zip -d "${SKILL_DIR}"
rm -f /tmp/pmcu-skill.zip
echo "[pmcu] installed: ${BIN_DIR}/pmcu + ${SKILL_DIR}/"
echo "[pmcu] ensure ${BIN_DIR} is on PATH, then run: pmcu status"
"${BIN_DIR}/pmcu" status
