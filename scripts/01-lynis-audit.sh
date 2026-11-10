#!/usr/bin/env bash
# =====================================================================
# 01-lynis-audit.sh
#
# Runs a Lynis system audit, archives the console output, the log and the
# report file, and appends the headline numbers to a history table.
#
# Usage:  bash scripts/01-lynis-audit.sh <label> [output-dir]
#   label = baseline | final   (anything you like, e.g. after-ssh)
#
# Produces in the output directory:
#   lynis-<label>-console.txt   full console output
#   lynis-<label>.log           /var/log/lynis.log
#   lynis-<label>-report.dat    /var/log/lynis-report.dat
#   lynis-history.txt           one line per run: index, warnings, suggestions
# =====================================================================
set -uo pipefail

LABEL="${1:-}"
OUT_DIR="${2:-$HOME/evidence}"

if [ -z "$LABEL" ]; then
  echo "usage: bash scripts/01-lynis-audit.sh <label> [output-dir]"
  exit 2
fi

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

mkdir -p "$OUT_DIR" || exit 1

if ! command -v lynis >/dev/null 2>&1; then
  echo "[*] Lynis not found - installing it"
  $SUDO apt-get update -qq && $SUDO apt-get install -y lynis || exit 1
fi

echo "[*] Running Lynis audit (label: $LABEL)"
$SUDO lynis audit system --quick --no-colors 2>&1 \
  | tee "$OUT_DIR/lynis-${LABEL}-console.txt"

DAT=/var/log/lynis-report.dat
$SUDO cp /var/log/lynis.log "$OUT_DIR/lynis-${LABEL}.log" 2>/dev/null
$SUDO cp "$DAT" "$OUT_DIR/lynis-${LABEL}-report.dat" 2>/dev/null
$SUDO chown "$(id -u):$(id -g)" "$OUT_DIR"/lynis-"${LABEL}"* 2>/dev/null

HI="$($SUDO grep -m1 '^hardening_index=' "$DAT" 2>/dev/null | cut -d= -f2)"
WARN="$($SUDO grep -c '^warning\[\]' "$DAT" 2>/dev/null)"
SUGG="$($SUDO grep -c '^suggestion\[\]' "$DAT" 2>/dev/null)"

{
  printf '%-10s %-20s index=%-4s warnings=%-4s suggestions=%-4s\n' \
    "$LABEL" "$(date -Is)" "${HI:-?}" "${WARN:-?}" "${SUGG:-?}"
} | tee -a "$OUT_DIR/lynis-history.txt"

echo
echo "================ TOP WARNINGS ================"
$SUDO grep '^warning\[\]' "$DAT" 2>/dev/null | cut -d= -f2- | head -20

echo
echo "================ HARDENING INDEX ================"
echo "hardening_index = ${HI:-unknown}   (report: $OUT_DIR/lynis-${LABEL}-report.dat)"
