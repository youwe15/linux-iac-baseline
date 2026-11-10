# Note to the instructor — scope confirmation

**Project title:** Automated CIS-Aligned Linux Security Hardening Using Ansible and Lynis
**Student:** *(name, roll number)*
**Subject:** Unix and Linux System Administration
**Duration:** 3 weeks

## What I am building

A **custom Linux security benchmark** (`IAC-Linux-Secure Baseline v1.0`) that is implemented as
code, applied to a server, and measured before and after with a security audit. The deliverable is
not a one-off hardened machine — it is a **reusable, version-controlled baseline** that turns a
fresh Ubuntu server into a defined secure state in one command.

## Environment

| Item | Choice | Reason |
|---|---|---|
| Hypervisor | VirtualBox | Isolated lab; snapshots make every change reversible |
| Server | **Ubuntu Server 24.04 LTS** | LTS release with security support; the CIS Ubuntu 24.04 benchmark is published for it |
| Target count | 1 VM at minimum, 2 for the demo (controller + target) | Two VMs demonstrate real remote automation |
| Automation | Ansible | Declarative, idempotent, supports dry runs — the correct IaC tool for OS configuration |
| Audit | Lynis | Independently measures the hardening index before and after |
| Reference | CIS Ubuntu Linux 24.04 LTS Benchmark, Level 1 server profile | Industry-standard control set |
| Version control | Git | Evidence of change control and reproducibility |

> **Note on the OS version:** I am using 24.04 **LTS** rather than 24.10. 24.10 is an interim
> release that reached end-of-life in July 2025, so package updates and automatic security updates
> — two of the benchmark controls — cannot be applied or demonstrated on it.

## The benchmark

Thirteen controls, grouped by administration area. Each control in the benchmark document records
its requirement, the risk it addresses, its CIS reference, the Ansible file that implements it, a
verification command, and a status of implemented / deferred / not applicable.

| Area | Controls |
|---|---|
| Patching | IAC-LNX-01 system fully patched, IAC-LNX-02 automatic security updates |
| Accounts and authentication | IAC-LNX-03 password aging, password quality, no empty passwords |
| Services | IAC-LNX-04 unnecessary services stopped, disabled and masked |
| Remote access | IAC-LNX-05 root SSH login disabled, IAC-LNX-06 SSH authentication hardened |
| Network | IAC-LNX-07 firewall default-deny with SSH only, IAC-LNX-11 kernel/network parameters |
| Logging and auditing | IAC-LNX-08 auditd with rules, IAC-LNX-10 journald, rsyslog, logrotate |
| File system | IAC-LNX-09 ownership and permissions of sensitive files |
| IaC quality | IAC-LNX-12 no secrets in Git, IAC-LNX-13 automation is idempotent |

Controls that are deliberately **not** implemented (AIDE file-integrity monitoring, custom AppArmor
profiles, separate partitions, `auditd -e 2` immutable rules, passwordless-only SSH) are documented
with a justification each. Explaining what was excluded, and why, is part of the assessment of the
project.

## Method

1. Build and patch the VM, snapshot it, record the baseline.
2. Run Lynis — record the hardening index, warnings and suggestions.
3. Map the audit findings onto CIS Level 1 recommendations and write the benchmark.
4. Implement every control as an Ansible role; run `--check --diff` before applying.
5. Verify each control independently with a shell script, not just with Ansible's own output.
6. Re-run Lynis and compare before/after.
7. Re-run the playbook to prove idempotency (`changed=0`).

## Unix administration topics covered

Installation and system setup; users, groups and PAM password policy; file ownership and
permission semantics; `apt` package management and patching; systemd services, sockets and timers;
SSH remote administration; firewall configuration with UFW; kernel and network parameters via
`sysctl`; logging with journald, rsyslog, logrotate and auditd; shell scripting for evidence
collection; configuration management and change control with Ansible and Git.

Security hardening is the vehicle for the project; the subject matter being assessed is operating
system administration.

## Deliverables

1. Benchmark document (13 controls with verification steps)
2. Ansible repository: 9 roles, one playbook, variable files, Git history
3. Initial and final Lynis reports with the hardening-index comparison
4. Per-control verification output (PASS/FAIL) and before/after table
5. Report and a 10-minute live demonstration

## Three-week plan

| Week | Focus | Output |
|---|---|---|
| 1 | Lab build, baseline audit, CIS mapping, benchmark document, Git repository | Benchmark v1.0 + baseline evidence |
| 2 | Implement the nine Ansible roles, test each one, full playbook run | Working IaC baseline, per-role evidence |
| 3 | Clean-slate re-run, final audit, comparison, report, rehearsal | Final report, comparison, demonstration |
