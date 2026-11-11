# Final Report — Automated CIS-Aligned Linux Security Hardening Using Ansible and Lynis

**Student:** *(your name, roll number)*
**Subject:** Unix and Linux System Administration
**Duration:** 3 weeks

---

## 1. Objective

To take a freshly-installed Linux server to a documented, measurable hardened state in two
complementary ways — **by hand** and **by Infrastructure as Code** — and to prove with an
independent audit that automation is not only faster but *more complete* than a manual pass.

## 2. Environment

| Component | Value |
|---|---|
| Hypervisor | Oracle VirtualBox 7.2 |
| Server OS | Ubuntu Server 24.04 LTS (x86_64) |
| Controller | Kali Linux — `192.168.x.xx`, user `youwe` |
| Target 1 (manual) | `linux_cis` — `192.168.x.xx`, user `youwe` |
| Target 2 (automated) | `linux_server2` — `192.168.x.xx`, user `uv` |
| Automation | Ansible 14 (core), `community.general`, `ansible.posix` |
| Audit | Lynis |
| Reference | CIS Ubuntu Linux 24.04 LTS Benchmark (Level 1, server profile) |
| Version control | Git / GitHub |

All machines share a VirtualBox NAT network (`192.168.1.0/24`); the controller reaches both
targets over SSH using key-based authentication.

## 3. Methodology

1. **Baseline** — patch the machine, snapshot it, run Lynis. Record the index: **56**.
2. **Manual pass** — harden `target1` area by area, running every command by hand and verifying
   each change: updates, accounts/passwords, SSH, services, firewall, permissions, logging,
   auditd, kernel `sysctl`.
3. **Audit again** — re-run Lynis on `target1`: **67**.
4. **Automation** — encode the same controls as nine Ansible roles and a variable file, then play
   them onto the pristine `target2`.
5. **Audit the automated box** — re-run Lynis on `target2`: **74**.
6. **Reconciliation & idempotency** — run the playbook twice to prove reproducibility and
   convergence.

## 4. The benchmark

A custom, CIS-informed baseline of **13 controls** (`IAC-LNX-01` … `IAC-LNX-13`), grouped by
administration area. Each control records its requirement, the risk it addresses, its CIS
reference, the Ansible file that implements it, and a verification command.

| ID | Control | Area |
|---|---|---|
| IAC-LNX-01 | System fully patched | Updates |
| IAC-LNX-02 | Automatic security updates enabled | Updates |
| IAC-LNX-03 | Account & password policy enforced | Accounts |
| IAC-LNX-04 | Unnecessary services disabled | Services |
| IAC-LNX-05 | SSH root login disabled | Remote access |
| IAC-LNX-06 | SSH authentication hardened | Remote access |
| IAC-LNX-07 | Firewall default-deny, SSH only | Network |
| IAC-LNX-08 | Audit logging with rules | Logging |
| IAC-LNX-09 | Sensitive file permissions correct | Filesystem |
| IAC-LNX-10 | Logging & log rotation configured | Logging |
| IAC-LNX-11 | Kernel/network parameters hardened | Network |
| IAC-LNX-12 | No secrets in version control | IaC hygiene |
| IAC-LNX-13 | Automation is idempotent | IaC hygiene |

The full requirement/verification detail lives in
`benchmark/IAC-Linux-Secure-Baseline-v1.0.md`.

## 5. Results

| Metric | Before | Manual (`target1`) | Automated (`target2`) |
|---|---|---|---|
| Lynis hardening index | **56** | **68** | **74** |
| Warnings | — | 0 | 0 |
| Suggestions | — | 41 | 41 (deferred items) |

The automated result **outscored** the manual result by 7 points. The reason is recorded below
under *Reconciliation* and is the central finding of this project.

## 6. Why automation outscored the manual pass

Running the playbook against the manually-hardened `target1` produced **13 changes** — the exact
places where the manual pass and the code diverged. Those 13 items are settings a human *could*
have applied but, in practice, did not on the first pass:

- extra SSH settings (`AllowTcpForwarding no`, `AllowAgentForwarding no`, `ClientAliveInterval`,
  `LogLevel VERBOSE`, `MaxSessions`)
- extra `sysctl` values (`kernel.yama.ptrace_scope`, `fs.protected_hardlinks`,
  `fs.protected_symlinks`, `net.ipv4.conf.*.secure_redirects`, `net.ipv6.conf.all.accept_ra`,
  `log_martians`, `icmp_ignore_bogus_error_responses`)
- a fuller `pwquality` policy (`difok`, `maxclassrepeat`, `enforcing`)
- differences in file naming (manual `99-hardening.conf` vs the role's `99-iac-baseline.conf`)

**Conclusion:** a code-defined baseline applies every control every time, and does not forget.
This is the concrete, measured argument for Infrastructure as Code in Linux administration.

## 7. Idempotency and repeatability

- On the pristine `target2`, the playbook ran once and produced the full baseline (repeatability).
- On `target2`, a second consecutive run reported **`changed=0`** (idempotency).

A control that reports no change on re-run is safe to re-apply in a change-management process —
that is the difference between a benchmark and a one-off script.

## 8. Deliberately deferred controls (and why)

| CIS area | Reason for deferral |
|---|---|
| AIDE file-integrity monitoring (CIS 1.3) | Requires a tuned baseline database; auditd already watches the key files |
| AppArmor profile tuning (CIS 1.6) | Enabled by default; writing custom profiles is a project of its own |
| Separate `/var`, `/tmp`, `/home` partitions (CIS 1.1) | VM uses a single installer partition |
| `auditd -e 2` immutable rules | Prevents rule changes during development |
| Passwordless-only SSH (`PasswordAuthentication no`) | No key-distribution infrastructure in the lab; the role refuses to disable it unless a key is already deployed |
| Full CIS Level 2 profile | Exceeds the three-week scope and would break lab usability |

Each is recorded as a reasoned exception, not an omission.

## 9. Challenges encountered

1. **NAT network semantics** — the Windows host cannot reach VirtualBox NAT guests, which forced
   guest-to-guest automation (the correct model anyway) and a decision to transfer the repository
   via Git rather than `scp`.
2. **Lynis hangs under a default-deny firewall** — UFW *drops* SYN probes silently, so Lynis's
   port scan waits for TCP timeouts. Resolved by auditing with the firewall temporarily disabled
   and re-enabled, then verified.
3. **Four defects caught by `--check --diff` before any real change** — three handler-name
   mismatches and a type mismatch (`int` vs `string`) in a firewall assertion. Every one was found
   in dry-run mode, which validated the practice of simulating before applying.
4. **`login.defs` vs `chage`** — the accounts control initially changed only defaults for *new*
   accounts, leaving the existing account un-aged; the role was extended to apply `chage` to
   existing human accounts too.

## 10. What was learned

- How to read and set Linux permission models, password aging/quality, systemd units, UFW rules,
  audit rules and kernel parameters by hand — and *why* each matters.
- That the `--check --diff` dry-run workflow catches defects before they reach a real system.
- That idempotency (`changed=0`) is what makes automation safe to re-run, and is measurable.
- That a manual hardening pass is a subset of what a complete code baseline enforces.

## 11. Conclusion

This project hardened two identical Ubuntu servers to a measurable, audit-backed state: one by
hand (56 → 68) and one by Ansible (56 → 74). The automation was faster, repeatable, idempotent,
and — because it never forgets — *more complete* than the manual pass. The deliverables are a
version-controlled benchmark, nine Ansible roles, before/after Lynis evidence, and a documented
list of reasoned exceptions.

## 12. Future work

- Add AIDE file-integrity monitoring and a CIS Level 2 pass.
- Scope the automation account's sudo privileges instead of blanket `NOPASSWD`.
- Run the baseline against a third, non-Ubuntu target to test portability of the roles.
- Integrate the playbook into a CI pipeline so every commit is dry-run tested.
