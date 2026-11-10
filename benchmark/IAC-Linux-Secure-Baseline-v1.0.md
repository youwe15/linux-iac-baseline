# IAC-Linux-Secure Baseline — v1.0

**A custom, version-controlled Linux server security benchmark**

| | |
|---|---|
| Baseline name | IAC-Linux-Secure Baseline |
| Version | 1.0 |
| Target platform | Ubuntu Server 24.04 LTS (x86_64, VirtualBox) |
| Primary reference | CIS Ubuntu Linux 24.04 LTS Benchmark (Level 1 server profile) |
| Secondary reference | Lynis audit findings (hardening index, warnings, suggestions) |
| Implementation | Ansible roles in this repository |
| Verification | `scripts/02-verify-controls.sh` + Lynis re-audit |
| Author | *(your name, student number, module, date)* |

## Disclaimer

This is a **CIS-informed custom baseline**, written for a three-week university project.
It is **not** the CIS Benchmark itself, and applying it does not make a system
"CIS certified". CIS Benchmark section numbers change between versions — when you cite
one in your report, cite the version you actually downloaded and check the number there.
The numbers below are indicative and are given with the section name so you can verify them.

## How each control is documented

| Field | Meaning |
|---|---|
| **ID** | Stable control identifier, `IAC-LNX-nn` |
| **Requirement** | What "secure" means here, in one testable sentence |
| **Risk addressed** | What goes wrong if it is not applied |
| **Reference** | CIS section and the Lynis test group that inspects it |
| **Implementation** | The Ansible role that enforces it |
| **Verification** | The command a human can run to prove it |
| **Expected result** | The exact output that counts as a pass |
| **Status** | `implemented`, `deferred` (with reason) or `n/a` |

---

## Summary

| ID | Control | Area | Status |
|---|---|---|---|
| IAC-LNX-01 | System is fully patched | Updates | implemented |
| IAC-LNX-02 | Automatic security updates enabled | Updates | implemented |
| IAC-LNX-03 | Account and password policy enforced | Accounts | implemented |
| IAC-LNX-04 | Unnecessary services disabled | Services | implemented |
| IAC-LNX-05 | SSH root login disabled | Remote access | implemented |
| IAC-LNX-06 | SSH authentication hardened | Remote access | implemented |
| IAC-LNX-07 | Firewall enabled, only SSH reachable | Network | implemented |
| IAC-LNX-08 | Audit logging enabled with rules | Logging | implemented |
| IAC-LNX-09 | Sensitive file permissions correct | File system | implemented |
| IAC-LNX-10 | Logging and log rotation configured | Logging | implemented |
| IAC-LNX-11 | Network and kernel parameters hardened | Network | implemented |
| IAC-LNX-12 | No secrets committed to version control | IaC hygiene | implemented |
| IAC-LNX-13 | Automation is idempotent | IaC hygiene | implemented |

---

## IAC-LNX-01 — System is fully patched

- **Requirement:** No pending package updates remain after the playbook runs.
- **Risk addressed:** Known vulnerabilities in unpatched packages are the most common way a
  server is compromised; a stale kernel also undermines every other control.
- **Reference:** CIS Section 1.2 *Configure Software Updates*; Lynis group `PKGS-`.
- **Implementation:** `roles/updates/tasks/main.yml` (`apt upgrade: safe`, `autoremove`).
- **Verification:** `apt list --upgradable` or `apt-get -s upgrade | grep -c '^Inst '`
- **Expected result:** `0` pending packages.
- **Notes:** A kernel update sets `/var/run/reboot-required`; the role reports this. Reboot,
  then re-run the playbook before taking your final audit. Show that in your report.

## IAC-LNX-02 — Automatic security updates enabled

- **Requirement:** `unattended-upgrades` is installed, enabled, and the daily upgrade timer runs.
- **Risk addressed:** The server drifts out of patch compliance between manual maintenance windows.
- **Reference:** CIS Section 1.2; Lynis group `PKGS-`.
- **Implementation:** `roles/updates/tasks/main.yml`.
- **Verification:** `cat /etc/apt/apt.conf.d/20auto-upgrades; systemctl list-timers apt-daily-upgrade.timer`
- **Expected result:** `APT::Periodic::Unattended-Upgrade "1";` and an active timer.

## IAC-LNX-03 — Account and password policy enforced

- **Requirement:** Password aging is set (`PASS_MAX_DAYS 365`, `PASS_MIN_DAYS 1`), password
  quality requires at least 12 characters and 3 character classes, `UMASK 027`, and no
  account has an empty password field.
- **Risk addressed:** Weak or never-expiring credentials allow brute force and credential reuse;
  an account with no password is an unauthenticated login.
- **Reference:** CIS Section 5.3 *Configure PAM* and 5.4 *User Accounts and Environment*;
  Lynis groups `AUTH-`, `ACCT-`.
- **Implementation:** `roles/accounts/tasks/main.yml` (`/etc/login.defs`, `/etc/security/pwquality.conf`).
- **Verification:** `grep -E '^(PASS_MAX_DAYS|UMASK)' /etc/login.defs; grep minlen /etc/security/pwquality.conf; sudo awk -F: '($2==""){print $1}' /etc/shadow`
- **Expected result:** `PASS_MAX_DAYS 365`, `UMASK 027`, `minlen = 12`, and no output from the awk.
- **Notes:** This control changes policy for *new* passwords. Existing accounts keep their old
  password until it is changed — `chage -l <user>` shows per-account aging.

## IAC-LNX-04 — Unnecessary services disabled

- **Requirement:** Services on the approved removal list (cups, avahi-daemon, rpcbind, telnet,
  xinetd, ftp, …) are stopped, disabled and masked if they are installed.
- **Risk addressed:** Every listening service is attack surface; printing and discovery daemons
  have no role on a headless server.
- **Reference:** CIS Section 2 *Services*; Lynis groups `BOOT-`, `NETW-`.
- **Implementation:** `roles/services/tasks/main.yml` (uses `service_facts`, so a service that is
  not installed is skipped rather than failing the run).
- **Verification:** `systemctl list-unit-files --state=enabled; ss -tulpn`
- **Expected result:** None of the listed services is enabled; only SSH (and required services) listen.
- **Notes:** Masking is used because it also blocks socket activation. The role never touches `ssh`.

## IAC-LNX-05 — SSH root login disabled

- **Requirement:** The effective `sshd` configuration contains `permitrootlogin no`.
- **Risk addressed:** Direct root login removes accountability and gives an attacker a known,
  maximum-privilege username to target.
- **Reference:** CIS Section 5.1 *Configure SSH Server*; Lynis group `SSH-`.
- **Implementation:** `roles/ssh/templates/99-iac-baseline.conf.j2`, deployed as a drop-in and
  validated with `sshd -t` before it is written.
- **Verification:** `sudo sshd -T | grep -i permitrootlogin`
- **Expected result:** `permitrootlogin no`
- **Evidence for the report:** `sudo ssh root@localhost` → `Permission denied (publickey,password)`.

## IAC-LNX-06 — SSH authentication hardened

- **Requirement:** `MaxAuthTries 3`, `LoginGraceTime 30`, `PermitEmptyPasswords no`,
  `X11Forwarding no`, `AllowAgentForwarding no`, `AllowTcpForwarding no`, `LogLevel VERBOSE`,
  and `AllowUsers` restricted (optional).
- **Risk addressed:** Unlimited authentication attempts invite brute force; forwarded X11 and
  agent sockets create lateral-movement paths.
- **Reference:** CIS Section 5.1; Lynis group `SSH-`.
- **Implementation:** same drop-in template.
- **Verification:** `sudo sshd -T | grep -Ei 'maxauthtries|x11forwarding|permitempty'`
- **Expected result:** `maxauthtries 3`, `x11forwarding no`, `permitemptypasswords no`.
- **Notes — deliberate decision:** `PasswordAuthentication` stays `yes` in v1.0 because the lab
  has no key infrastructure. The role refuses to set it to `no` unless an `authorized_keys` file
  exists, so the playbook cannot lock you out. Record this as a *documented exception*.

## IAC-LNX-07 — Firewall enabled, only SSH reachable

- **Requirement:** `ufw` is active, default incoming is `deny`, default outgoing `allow`, and the
  SSH port is explicitly permitted.
- **Risk addressed:** Unrestricted inbound access exposes every service that is listening, including
  ones you did not intend to publish.
- **Reference:** CIS Section 3.3 *Configure Firewall*; Lynis groups `FIRE-`, `NETW-`.
- **Implementation:** `roles/firewall/tasks/main.yml`. Ordering is deliberate: allow SSH → enable.
- **Verification:** `sudo ufw status verbose`
- **Expected result:** `Status: active`, `Default: deny (incoming), allow (outgoing)`,
  `22/tcp ALLOW IN`.
- **Notes:** Reordering the tasks in that role will cut your own SSH session. The role asserts that
  the SSH port appears in `ufw status` before the play continues.

## IAC-LNX-08 — Audit logging enabled with rules

- **Requirement:** `auditd` is installed, active and enabled at boot, with baseline rules watching
  identity files, sudo configuration, sshd configuration, cron and privileged `execve`.
- **Risk addressed:** Without audit records you cannot reconstruct who changed `/etc/shadow` or
  escalated privileges.
- **Reference:** CIS Section 4.1 *Configure System Accounting (auditd)*; Lynis group `LOGG-`.
- **Implementation:** `roles/audit/` (rules template + `augenrules --load` handler).
- **Verification:** `systemctl is-active auditd; sudo auditctl -l; sudo ausearch -k identity -ts today`
- **Expected result:** `active`, and one or more `-w /etc/shadow ... -k identity` rules.
- **Notes:** `auditd.service` has `RefuseManualStop=yes`, so rules are reloaded with
  `augenrules --load`, never `systemctl restart auditd`. The `-e 2` (immutable) flag is
  deliberately **not** set, otherwise you could not iterate during the project.

## IAC-LNX-09 — Sensitive file permissions correct

- **Requirement:** `/etc/passwd` 0644 root:root, `/etc/shadow` and `/etc/gshadow` 0640 root:shadow,
  `/etc/sudoers` 0440 root:root, `/etc/ssh/sshd_config` 0600, `/etc/crontab` 0600, `/root` 0700,
  cron directories 0700.
- **Risk addressed:** A world-readable shadow file hands an attacker offline password cracking.
- **Reference:** CIS Section 6.1 *System File Permissions*; Lynis group `FILE-`.
- **Implementation:** `roles/permissions/tasks/main.yml` (stats first, then enforces only existing paths).
- **Verification:** `stat -c '%a %U:%G %n' /etc/passwd /etc/shadow /etc/sudoers`
- **Expected result:** `644 root:root /etc/passwd`, `640 root:shadow /etc/shadow`, `440 root:root /etc/sudoers`.

## IAC-LNX-10 — Logging and log rotation configured

- **Requirement:** `rsyslog` active, `logrotate.timer` enabled, journald configured for persistent
  storage with a size cap.
- **Risk addressed:** Logs that are lost on reboot, or that fill the disk, destroy both forensic
  evidence and availability.
- **Reference:** CIS Sections 4.2 *Configure Logging* and 4.3 *logrotate*; Lynis group `LOGG-`.
- **Implementation:** `roles/logging/`.
- **Verification:** `systemctl is-enabled logrotate.timer; journalctl --disk-usage; cat /etc/systemd/journald.conf.d/99-iac-baseline.conf`
- **Expected result:** `enabled`, a bounded disk usage figure, `Storage=persistent`.

## IAC-LNX-11 — Network and kernel parameters hardened

- **Requirement:** Reverse-path filtering, no source routing, no ICMP redirects, SYN cookies,
  `dmesg_restrict`, `kptr_restrict`, ASLR and `ptrace_scope` set as specified in
  `group_vars/all.yml`, persisted in `/etc/sysctl.d/99-iac-baseline.conf`.
- **Risk addressed:** Spoofed traffic, information leaks through kernel pointers and dmesg, and
  memory-corruption exploitation become easier without these settings.
- **Reference:** CIS Sections 3.1/3.2 *Network Parameters* and 1.5 *Additional Process Hardening*;
  Lynis groups `KRNL-`, `NETW-`.
- **Implementation:** `roles/sysctl/tasks/main.yml` (`ansible.posix.sysctl`, `reload: true`).
- **Verification:** `sysctl -n net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter kernel.dmesg_restrict`
- **Expected result:** `1`, `1`, `1`.
- **Notes:** `net.ipv6.conf.all.accept_ra=0` is only correct if the server does not use IPv6
  router advertisements. In a NAT/host-only VirtualBox lab it is safe; on a real network, check first.

## IAC-LNX-12 — No secrets committed to version control

- **Requirement:** The repository contains no private keys, no `.vault_pass`, and no plaintext
  password variables. `.gitignore` excludes the usual offenders.
- **Risk addressed:** A pushed key or password is compromised the moment it reaches a remote, even
  if you delete it in a later commit.
- **Reference:** IaC hygiene — not a CIS control.
- **Implementation:** `.gitignore`, documented use of `ansible-vault` for any real secret.
- **Verification:** `git ls-files | grep -Ei 'id_rsa|\.pem|vault_pass'` (expect no output) and a
  manual read of `group_vars/all.yml`.
- **Expected result:** no output.

## IAC-LNX-13 — Automation is idempotent

- **Requirement:** A second consecutive playbook run reports `changed=0` on every host.
- **Risk addressed:** Non-idempotent automation cannot be safely re-run; it drifts and it hides
  real work inside noise.
- **Reference:** IaC hygiene — not a CIS control.
- **Implementation:** every role uses declarative modules (`apt`, `copy`, `template`, `lineinfile`,
  `file`, `systemd`, `ufw`, `sysctl`) instead of `command`/`shell` for state changes.
- **Verification:** run `ansible-playbook -i inventory.ini site.yml -K` twice.
- **Expected result:** second run ends with `changed=0`.
- **Notes:** Tasks that only *read* state are marked `changed_when: false`; that is why the
  verification tasks do not appear in the change count.

---

## Deliberately deferred (and why)

| CIS area | Why it is out of scope for v1.0 |
|---|---|
| AIDE / file integrity monitoring (CIS 1.3) | Needs a tuned baseline database; too heavy for three weeks, and auditd already covers the key files. |
| AppArmor profile tuning (CIS 1.6) | Enabled by default on Ubuntu; writing custom profiles is a project of its own. |
| Separate `/var`, `/tmp`, `/home` partitions (CIS 1.1) | The VM uses a single partition from the installer; re-partitioning adds no demonstrable skill for this brief. |
| `auditd -e 2` immutable rules | Prevents rule changes, which blocks iterative work. Correct for production, wrong mid-project. |
| Passwordless-only SSH with `AllowUsers` | No key infrastructure in the lab; `PasswordAuthentication yes` is recorded as an exception. |
| Full CIS Level 2 profile | Exceeds the three-week scope and would break the lab's usability. |

Each of these is a legitimate "skipped control" answer for your presentation. Say what you
skipped, why, and what you would do with more time — that is what distinguishes a good report.

## Evidence checklist

- [ ] `evidence/baseline-*.txt` — manual baseline before any change
- [ ] Lynis report + hardening index, before
- [ ] `ansible-playbook --check --diff` output (the plan)
- [ ] First apply output showing changes
- [ ] Second apply output showing `changed=0`
- [ ] `scripts/02-verify-controls.sh` output: all PASS
- [ ] Lynis report + hardening index, after
- [ ] Before/after table with numbers
- [ ] Screenshots of `ufw status verbose`, `sshd -T`, `auditctl -l`, `stat` on sensitive files
