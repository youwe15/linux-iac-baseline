#!/usr/bin/env bash
# =====================================================================
# 00-collect-baseline.sh
#
# Collects a plain-text snapshot of the system BEFORE hardening.
# This is the "document the baseline" deliverable and is independent of
# Lynis: if Lynis is unavailable, you still have evidence.
#
# Usage:  bash scripts/00-collect-baseline.sh [output-dir]
# Default output: ~/evidence
# =====================================================================
set -uo pipefail

OUT_DIR="${1:-$HOME/evidence}"
HOST="$(hostname -s)"
TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR" || exit 1
FILE="$OUT_DIR/baseline-${HOST}-${TS}.txt"

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

section() { printf '\n========== %s ==========\n' "$1"; }
sh()      { section "$1"; bash -c "$2" 2>&1 || echo "(not available or no output)"; }

collect() {
  echo "IAC-Linux-Secure Baseline v1.0 - SYSTEM BASELINE"
  echo "file:          $FILE"
  echo "collected_at:  $(date -Is)"
  echo "collected_by:  $(id -un)@$(hostname -f 2>/dev/null || hostname)"

  sh "Operating system"      'cat /etc/os-release'
  sh "Kernel and architecture" 'uname -a'
  sh "Virtualisation"        'systemd-detect-virt || true'
  sh "Hardware"              'nproc; free -h'
  sh "File systems"          'df -hT | grep -vE "tmpfs|udev"'
  sh "Block devices"         'lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null'

  sh "Local user accounts (uid >= 1000)" \
     "awk -F: '\$3>=1000 && \$3<65534 {printf \"%-15s uid=%-6s shell=%s\\n\", \$1, \$3, \$7}' /etc/passwd"
  sh "Accounts with empty passwords" \
     "awk -F: '\$2==\"\" {print \$1}' /etc/shadow"
  sh "Password aging policy" \
     'grep -E "^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE|UMASK)" /etc/login.defs'
  sh "Password quality policy" \
     'grep -vE "^\s*#|^\s*$" /etc/security/pwquality.conf 2>/dev/null'
  sh "Members of the sudo group" 'getent group sudo'
  sh "Sudo configuration" \
     'grep -rhvE "^\s*#|^\s*$" /etc/sudoers /etc/sudoers.d/ 2>/dev/null'

  sh "Listening sockets" 'ss -tulpn'
  sh "Enabled services" \
     'systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend'
  sh "Running services" \
     'systemctl list-units --type=service --state=running --no-pager --no-legend'
  sh "Enabled timers" \
     'systemctl list-timers --all --no-pager'
  sh "Failed units" 'systemctl --failed --no-pager'

  sh "Firewall status" '(ufw status verbose 2>/dev/null || echo "ufw not installed")'
  sh "Effective SSH configuration" \
     'sshd -T 2>/dev/null | sort || echo "sshd -T failed"'
  sh "SSH configuration files" \
     'ls -l /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null'

  sh "Sensitive file permissions" \
     'stat -c "%a %U:%G %n" /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers /etc/ssh/sshd_config /etc/crontab /root 2>/dev/null'

  sh "Kernel hardening parameters" \
     'sysctl kernel.dmesg_restrict kernel.kptr_restrict kernel.randomize_va_space \
        net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter \
        net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.accept_source_route 2>/dev/null'

  sh "Pending package updates" \
     'apt-get -s upgrade 2>/dev/null | grep "^Inst " | wc -l'
  sh "Automatic updates configuration" \
     'cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; \
      systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null'
  sh "Installed package count" 'dpkg -l | grep -c "^ii"'

  sh "Audit daemon" \
     'systemctl is-active auditd 2>/dev/null; auditctl -l 2>/dev/null | head -20'
  sh "Journal disk usage" 'journalctl --disk-usage 2>/dev/null'
  sh "Log directory" 'ls -ld /var/log /var/log/auth.log 2>/dev/null'

  echo
  echo "Baseline written to: $FILE"
}

collect 2>&1 | tee "$FILE"
