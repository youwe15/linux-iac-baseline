# IAC-Linux-Secure Baseline v1.0

**Project:** Automated CIS-Aligned Linux Security Hardening Using Ansible and Lynis
**Subject:** Unix and Linux System Administration
**Target platform:** Ubuntu Server 24.04 LTS (VirtualBox)

A version-controlled security baseline for a Linux server. The baseline is *defined as code*
(Ansible), *evidenced by audit* (Lynis), and *verified control by control* (a shell script).

```
Fresh Ubuntu Server
        |
        |-- 1. collect baseline evidence      -> evidence/baseline-*.txt
        |-- 2. Lynis audit (before)           -> hardening index + warnings
        |-- 3. ansible-playbook site.yml      -> 13 controls applied
        |-- 4. verify controls                -> PASS/FAIL table
        |-- 5. Lynis audit (after)            -> hardening index improved
        '-- 6. run playbook again             -> changed=0 (idempotent)
```

---

## 1. How many VMs do you need?

| Setup | VMs | RAM needed | When to use it |
|---|---|---|---|
| **Minimum (start here today)** | 1 | 2–4 GB | Ansible runs on the same VM it manages (`ansible_connection=local`). Still real IaC. |
| **Recommended (for the demo)** | 2 | ~5 GB | Controller + target. Proves real remote automation over SSH, and lets you re-run the playbook on a *fresh* target to show repeatability. |

You do **not** need three or more VMs. If you want to "prove repeatability on a clean machine",
revert the target's VirtualBox snapshot instead of building a third VM.

Both modes work with the same playbook:

```bash
# one VM
ansible-playbook -i inventory-local.ini site.yml -K
# two VMs
ansible-playbook -i inventory.ini site.yml -K
```

## 2. Ubuntu version warning

**Use Ubuntu Server 24.04 LTS, not 24.10.**

24.10 is an *interim* release with only 9 months of support, so it has been end-of-life since
July 2025. Consequences for this project:

- `apt update` fails or points at `old-releases.ubuntu.com`, so **IAC-LNX-01 (patching) and
  IAC-LNX-02 (automatic security updates) cannot be evidenced** — that is 2 of your 13 controls.
- Lynis reports a large number of unpatched packages, which pollutes your before/after comparison.
- The CIS Benchmark you are aligning to is published for **24.04 LTS**.

Reinstalling takes about 30 minutes and removes all of these problems. If your teacher *requires*
24.10, keep it and document the limitation explicitly in the report — but expect lower scores.

## 3. Quickstart

```bash
# on the target / single VM
git clone <your-repo-url> ~/linux-iac-baseline        # or scp the zip
cd ~/linux-iac-baseline

sudo apt update && sudo apt install -y lynis ansible git
ansible-galaxy collection install -r requirements.yml

# 1. evidence before
bash scripts/00-collect-baseline.sh ~/evidence
bash scripts/01-lynis-audit.sh baseline ~/evidence

# 2. preview, then apply
ansible-playbook -i inventory-local.ini site.yml --syntax-check
ansible-playbook -i inventory-local.ini site.yml --check --diff -K
ansible-playbook -i inventory-local.ini site.yml -K

# 3. evidence after
bash scripts/02-verify-controls.sh
bash scripts/01-lynis-audit.sh final ~/evidence
```

## 4. The 13 controls

| ID | Control | Applied by | Verified by |
|---|---|---|---|
| IAC-LNX-01 | System fully patched | `roles/updates` | `scripts/02-verify-controls.sh` |
| IAC-LNX-02 | Automatic security updates enabled | `roles/updates` | `20auto-upgrades`, timers |
| IAC-LNX-03 | Account & password policy enforced | `roles/accounts` | `login.defs`, `pwquality.conf` |
| IAC-LNX-04 | Unnecessary services disabled | `roles/services` | `systemctl is-enabled` |
| IAC-LNX-05 | SSH root login disabled | `roles/ssh` | `sshd -T` |
| IAC-LNX-06 | SSH authentication hardened | `roles/ssh` | `sshd -T` |
| IAC-LNX-07 | Firewall enabled, only SSH allowed | `roles/firewall` | `ufw status verbose` |
| IAC-LNX-08 | Audit logging (auditd) enabled | `roles/audit` | `systemctl is-active auditd` |
| IAC-LNX-09 | Sensitive file permissions correct | `roles/permissions` | `stat -c '%a %U:%G'` |
| IAC-LNX-10 | Logging & log rotation configured | `roles/logging` | `logrotate.timer`, journald conf |
| IAC-LNX-11 | Network kernel settings hardened | `roles/sysctl` | `sysctl -n ...` |
| IAC-LNX-12 | No secrets committed to Git | manual + `.gitignore` | repository review |
| IAC-LNX-13 | Automation is idempotent | `site.yml` | second run: `changed=0` |

Full requirement text, CIS references, verification commands and status:
**[`benchmark/IAC-Linux-Secure-Baseline-v1.0.md`](benchmark/IAC-Linux-Secure-Baseline-v1.0.md)**

## 5. Repository layout

```
linux-iac-baseline/
├── README.md
├── ansible.cfg
├── inventory.ini              # controller -> target (two-VM mode)
├── inventory-local.ini        # single-VM mode
├── requirements.yml           # ansible collections
├── site.yml                   # the baseline entry point
├── group_vars/all.yml         # every tunable value in one place
├── roles/
│   ├── updates/               # IAC-LNX-01, -02
│   ├── accounts/              # IAC-LNX-03
│   ├── services/              # IAC-LNX-04
│   ├── ssh/                   # IAC-LNX-05, -06
│   ├── firewall/              # IAC-LNX-07
│   ├── audit/                 # IAC-LNX-08
│   ├── permissions/           # IAC-LNX-09
│   ├── logging/               # IAC-LNX-10
│   └── sysctl/                # IAC-LNX-11
├── scripts/
│   ├── 00-collect-baseline.sh # manual evidence before hardening
│   ├── 01-lynis-audit.sh      # run + archive a Lynis audit
│   └── 02-verify-controls.sh  # PASS/FAIL for every control
├── benchmark/
│   └── IAC-Linux-Secure-Baseline-v1.0.md
├── docs/
│   ├── day1-vm-setup.md       # install + networking + Ansible, step by step
│   ├── week-plan.md           # 21-day plan
│   └── demo-script.md         # 10-minute demonstration runbook
└── evidence/                  # curated copies of reports, screenshots
```

## 6. Safety rules (read before the first run)

1. Work only inside the VM. Never run these playbooks against your Windows host.
2. Take a VirtualBox snapshot named `fresh-install` **before** the first playbook run.
3. Keep the VM console window open while SSH settings are being applied.
4. Never set `ssh_password_authentication: "no"` until key-based login is proven to work.
5. The firewall role allows SSH **before** it enables UFW — do not reorder those tasks.
6. Never commit passwords, private keys or tokens. Use `ansible-vault` if a secret is unavoidable.
7. Run `--check --diff` first, and read the diff.

## 7. Why this is a Unix administration project, not just a security project

| Course topic | Where it appears |
|---|---|
| Installation & system setup | `docs/day1-vm-setup.md`, netplan networking |
| User/group management, authentication | `roles/accounts`, `/etc/login.defs`, PAM `pwquality` |
| File systems & permissions | `roles/permissions`, `stat`, `chmod`/`chown` semantics |
| Package management | `roles/updates`, `apt`, `unattended-upgrades` |
| Processes & services | `roles/services`, `systemctl`, `service_facts` |
| Remote administration | `roles/ssh`, key-based SSH, `sshd -T` |
| Networking & firewall | `roles/firewall`, `ufw`, `ss`, netplan |
| Boot & startup behaviour | `systemd` units, timers, sockets, enabled-state |
| Logging & monitoring | `roles/logging`, `journald`, `rsyslog`, `logrotate`, `auditd` |
| Shell scripting | `scripts/*.sh` |
| Automation / configuration management | Ansible roles, YAML, idempotency |
| Documentation & change control | this repo, benchmark, Git history, evidence |
