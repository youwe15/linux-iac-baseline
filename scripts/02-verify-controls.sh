#!/usr/bin/env bash
# =====================================================================
# 02-verify-controls.sh
#
# Independently verifies every control in IAC-Linux-Secure Baseline v1.0
# and prints a PASS / FAIL / NOTE table.
#
# Run this on the hardened host, from the repository root:
#   bash scripts/02-verify-controls.sh
#
# Exit code: 0 if every automated check passed, 1 otherwise.
# =====================================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

PASS=0; FAIL=0; NOTE=0
pass() { printf '[ PASS ] %-11s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
fail() { printf '[ FAIL ] %-11s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
note() { printf '[ NOTE ] %-11s %s\n' "$1" "$2"; NOTE=$((NOTE+1)); }

printf 'IAC-Linux-Secure Baseline v1.0 - control verification\n'
printf 'host: %s   kernel: %s   date: %s\n' "$(hostname)" "$(uname -r)" "$(date -Is)"
printf '%s\n' '----------------------------------------------------------------------------'

# ---------------------------------------------------------------- IAC-LNX-01
if command -v apt-get >/dev/null 2>&1; then
  pending=$($SUDO apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst ')
  if [ "${pending:-1}" -eq 0 ]; then
    pass IAC-LNX-01 "no pending package updates"
  else
    fail IAC-LNX-01 "$pending package(s) still pending"
  fi
else
  note IAC-LNX-01 "apt-get not found"
fi

# ---------------------------------------------------------------- IAC-LNX-02
if grep -qs 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades \
   && systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null; then
  pass IAC-LNX-02 "unattended-upgrades configured, timer enabled"
else
  fail IAC-LNX-02 "automatic security updates not fully configured"
fi

# ---------------------------------------------------------------- IAC-LNX-03
ok=1; why=""
grep -qE '^PASS_MAX_DAYS[[:space:]]+365' /etc/login.defs || { ok=0; why="$why login.defs;"; }
grep -qE '^[[:space:]]*minlen[[:space:]]*=[[:space:]]*12' /etc/security/pwquality.conf 2>/dev/null \
  || { ok=0; why="$why pwquality.minlen;"; }
[ -z "$($SUDO awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null)" ] \
  || { ok=0; why="$why empty-password-accounts;"; }
if [ "$ok" -eq 1 ]; then
  pass IAC-LNX-03 "password aging, quality and no empty passwords"
else
  fail IAC-LNX-03 "incomplete:$why"
fi

# ---------------------------------------------------------------- IAC-LNX-04
bad=""
for s in avahi-daemon cups cups-browsed rpcbind nfs-server vsftpd telnet xinetd slapd squid; do
  systemctl is-enabled --quiet "$s" 2>/dev/null && bad="$bad $s"
done
if [ -z "$bad" ]; then
  pass IAC-LNX-04 "no unnecessary enabled services"
else
  fail IAC-LNX-04 "still enabled:$bad"
fi

# ---------------------------------------------------------------- IAC-LNX-05/06
SSH_EFF="$($SUDO sshd -T 2>/dev/null)"
if [ -n "$SSH_EFF" ]; then
  echo "$SSH_EFF" | grep -qi '^permitrootlogin no' \
    && pass IAC-LNX-05 "PermitRootLogin no" \
    || fail IAC-LNX-05 "root SSH login still permitted"
  if echo "$SSH_EFF" | grep -qi '^maxauthtries 3' \
     && echo "$SSH_EFF" | grep -qi '^x11forwarding no' \
     && echo "$SSH_EFF" | grep -qi '^permitemptypasswords no'; then
    pass IAC-LNX-06 "MaxAuthTries=3, X11 off, empty passwords off"
  else
    fail IAC-LNX-06 "SSH authentication settings incomplete"
  fi
  note IAC-LNX-06 "PasswordAuthentication = $(echo "$SSH_EFF" | awk '/^passwordauthentication/{print $2}') (a documented choice, not a pass/fail)"
else
  fail IAC-LNX-05 "sshd -T failed - cannot read effective config"
  fail IAC-LNX-06 "sshd -T failed - cannot read effective config"
fi

# ---------------------------------------------------------------- IAC-LNX-07
UFW="$($SUDO ufw status verbose 2>/dev/null)"
if echo "$UFW" | grep -q 'Status: active' \
   && echo "$UFW" | grep -q 'Default: deny (incoming)'; then
  echo "$UFW" | grep -qE '^22(/tcp)?[[:space:]]+ALLOW' \
    && pass IAC-LNX-07 "ufw active, default deny incoming, SSH allowed" \
    || fail IAC-LNX-07 "ufw active but SSH is not explicitly allowed"
else
  fail IAC-LNX-07 "ufw is not active with a default-deny incoming policy"
fi

# ---------------------------------------------------------------- IAC-LNX-08
if systemctl is-active --quiet auditd 2>/dev/null \
   && $SUDO auditctl -l 2>/dev/null | grep -q 'identity'; then
  pass IAC-LNX-08 "auditd active with baseline rules loaded"
else
  fail IAC-LNX-08 "auditd inactive or baseline rules not loaded"
fi

# ---------------------------------------------------------------- IAC-LNX-09
perm_ok=1; perm_bad=""
check_perm() {
  local path="$1" want="$2" got
  got="$(stat -c '%a %U:%G' "$path" 2>/dev/null || echo MISSING)"
  if [ "$got" != "$want" ]; then perm_ok=0; perm_bad="$perm_bad $path($got)"; fi
}
check_perm /etc/passwd            "644 root:root"
check_perm /etc/shadow            "640 root:shadow"
check_perm /etc/group             "644 root:root"
check_perm /etc/gshadow           "640 root:shadow"
check_perm /etc/sudoers           "440 root:root"
check_perm /etc/ssh/sshd_config   "600 root:root"
check_perm /etc/crontab           "600 root:root"
check_perm /root                  "700 root:root"
if [ "$perm_ok" -eq 1 ]; then
  pass IAC-LNX-09 "sensitive file ownership and modes correct"
else
  fail IAC-LNX-09 "wrong permissions:$perm_bad"
fi

# ---------------------------------------------------------------- IAC-LNX-10
if systemctl is-enabled --quiet logrotate.timer 2>/dev/null \
   && [ -f /etc/systemd/journald.conf.d/99-iac-baseline.conf ] \
   && systemctl is-active --quiet rsyslog 2>/dev/null; then
  pass IAC-LNX-10 "logrotate timer, persistent journal, rsyslog active"
else
  fail IAC-LNX-10 "logging or log rotation not fully configured"
fi

# ---------------------------------------------------------------- IAC-LNX-11
sys_ok=1; sys_bad=""
check_sysctl() {
  local key="$1" want="$2" got
  got="$(sysctl -n "$key" 2>/dev/null)"
  if [ "$got" != "$want" ]; then sys_ok=0; sys_bad="$sys_bad $key=$got"; fi
}
check_sysctl kernel.dmesg_restrict 1
check_sysctl kernel.kptr_restrict 2
check_sysctl kernel.randomize_va_space 2
check_sysctl net.ipv4.tcp_syncookies 1
check_sysctl net.ipv4.conf.all.rp_filter 1
check_sysctl net.ipv4.conf.all.accept_redirects 0
check_sysctl net.ipv4.conf.all.accept_source_route 0
if [ "$sys_ok" -eq 1 ]; then
  pass IAC-LNX-11 "kernel and network parameters hardened"
else
  fail IAC-LNX-11 "wrong values:$sys_bad"
fi

# ---------------------------------------------------------------- IAC-LNX-12
if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$REPO_DIR" ls-files | grep -qE '(^|/)(id_rsa|id_ed25519|\.vault_pass|vault_pass)'; then
    fail IAC-LNX-12 "key material or vault password is tracked by git"
  else
    pass IAC-LNX-12 "no key material or vault password tracked by git"
  fi
  note IAC-LNX-12 "also review group_vars/all.yml by eye for plaintext secrets"
else
  note IAC-LNX-12 "not a git repository - review secrets manually"
fi

# ---------------------------------------------------------------- IAC-LNX-13
note IAC-LNX-13 "idempotency cannot be checked from a script:"
note IAC-LNX-13 "  run 'ansible-playbook -i inventory.ini site.yml -K' twice"
note IAC-LNX-13 "  the second run must report changed=0"

printf '%s\n' '----------------------------------------------------------------------------'
printf 'RESULT: %d passed, %d failed, %d note(s)\n' "$PASS" "$FAIL" "$NOTE"

if [ "$FAIL" -gt 0 ]; then
  printf 'Review the FAIL lines above, fix, then re-run the playbook.\n'
  exit 1
fi
printf 'All automated controls passed.\n'
