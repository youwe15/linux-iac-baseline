# 21-day execution plan

Three weeks is about 15 working days of real effort. The plan below front-loads the lab build so
that a broken VM on day 12 cannot destroy the project, and it keeps every day's output as something
you can paste into the report.

Legend: **[must]** = graded evidence, **[nice]** = improves the report if time allows.

---

## Week 1 — Baseline and benchmark (days 1–7)

| Day | Work | Output you keep |
|---|---|---|
| 1 | Build the VM, patch it, snapshot `fresh-install`, install Lynis/Ansible/Git, set up SSH keys. `docs/day1-vm-setup.md`. **[must]** | Screenshot of `hostnamectl`, snapshot name |
| 2 | Run `00-collect-baseline.sh` and the first Lynis audit. Read the report properly: index, warnings, suggestions. **[must]** | `evidence/baseline-*.txt`, `lynis-baseline-*`, index number |
| 3 | Turn Lynis warnings into a findings table: finding → which control area it belongs to → priority. **[must]** | `evidence/findings-table.md` |
| 4 | Download the CIS Ubuntu 24.04 LTS Benchmark PDF. Read the Level 1 server profile only. Map 10–15 CIS items onto your controls. **[must]** | CIS mapping column in the benchmark doc |
| 5 | Finalise `benchmark/IAC-Linux-Secure-Baseline-v1.0.md`: requirement, risk, reference, verification for every control. Decide what is deferred and why. **[must]** | Benchmark v1.0 committed to Git |
| 6 | `git init`, first commit, push to GitHub/GitLab. Write the README so a stranger can run it. **[must]** | Repository URL, first commit |
| 7 | Buffer / catch-up. If you are on schedule, start the `updates`, `accounts` and `permissions` roles. | — |

**End of week 1 you must have:** a patched VM, a baseline audit, a written benchmark, and a Git
repository. No hardening yet.

---

## Week 2 — Implement the baseline as code (days 8–14)

Build one role per day, and after each role run `--check --diff`, then apply, then verify manually.
Do not write all nine roles and then debug them all at once.

| Day | Roles / work | Verification you record |
|---|---|---|
| 8 | `updates` (IAC-LNX-01, 02) | `apt list --upgradable`, `cat 20auto-upgrades` |
| 9 | `accounts` (IAC-LNX-03) | `chage -l student`, `grep minlen`, weak-password rejection with `passwd` |
| 10 | `ssh` (IAC-LNX-05, 06) — keep the console open | `sshd -T`, failed `ssh root@localhost`, successful `ssh student@...` |
| 11 | `firewall` (IAC-LNX-07) + `services` (IAC-LNX-04) | `ufw status verbose`, `ss -tulpn`, `systemctl is-enabled` |
| 12 | `permissions` (IAC-LNX-09) + `logging` (IAC-LNX-10) | `stat` output, `journalctl --disk-usage`, `logrotate.timer` |
| 13 | `audit` (IAC-LNX-08) + `sysctl` (IAC-LNX-11) | `auditctl -l`, `ausearch -k identity`, `sysctl -n ...` |
| 14 | Full `site.yml` run, `02-verify-controls.sh`, fix failures, commit each role separately | All PASS, commit history, second-run `changed=0` |

Rules for week 2:

- Never apply a role over SSH without the VM console open.
- Commit after each working role, with a message naming the control IDs.
- If you break the VM: revert to `fresh-install`, replay your playbook — this is exactly the point
  of IaC, and it is a great thing to say in the viva.

**End of week 2 you must have:** a playbook that runs green from a clean snapshot in one command.

---

## Week 3 — Prove it, measure it, present it (days 15–21)

| Day | Work | Output |
|---|---|---|
| 15 | Revert to `fresh-install`, run the playbook once from scratch, time it. This is your repeatability proof. | Screenshot of a clean run |
| 16 | Run the final Lynis audit, build the before/after table (index, warnings, suggestions, per-area changes). **[must]** | `lynis-final-*`, comparison table |
| 17 | Write the report: scope, method, benchmark, results, exceptions, lessons learned. **[must]** | `docs/final-report.md` (draft) |
| 18 | Build 8–10 slides: problem, method, architecture diagram, benchmark table, results graph, exceptions, conclusion. **[must]** | Slides |
| 19 | Rehearse the demo end to end with `docs/demo-script.md`. Time it. Fix anything that needs a password you do not have. | Timed run under 10 minutes |
| 20 | Buffer: fix gaps, add screenshots, proofread. Check every number in the report against the evidence files. | Final report |
| 21 | Submit and present. | — |

---

## Marks-per-hour priorities

If you fall behind, protect these in order:

1. A working `site.yml` that runs twice with `changed=0` (IAC-LNX-13). This is the single most
   convincing artifact in the whole project.
2. Before/after Lynis hardening index with the report files attached.
3. The benchmark document with explicit verification steps.
4. Explicit, reasoned exceptions ("I skipped X because Y").
5. Screenshots of the actual hardened state.

Do not spend week 3 writing prose you could have written on day 5, and do not add an eleventh role
in the last two days.

---

## What to say if your teacher asks "is this really a Unix administration project?"

> The project exercises the standard Unix administration domains end to end: installation and
> partition layout, users and groups, PAM password policy, file ownership and modes, `apt` package
> management and patching, systemd services, sockets and timers, SSH remote administration, UFW
> firewalling, kernel and network parameters through `sysctl`, logging through journald, rsyslog,
> logrotate and auditd, plus shell scripting for evidence collection. Security hardening is the
> vehicle; the subject matter is operating-system administration, and the deliverables are
> reproducible because they are code rather than one-off commands.
