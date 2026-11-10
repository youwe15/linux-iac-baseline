# 10-minute demonstration runbook

Print this. Rehearse it twice. Have two terminal tabs open and the VM window visible.

## Before you start (5 minutes earlier)

```bash
# snapshot the current state so the demo cannot be ruined
# VirtualBox -> Machine -> Take Snapshot -> "pre-demo"

cd ~/linux-iac-baseline
ls evidence/                     # the reports you will show
sudo ufw status verbose          # make sure the lab is healthy
```

Have ready: the VM console window, one SSH terminal, and the browser tab on the Git repository.

---

## Minute 0–1 — The problem, in one sentence

> "A default Ubuntu server is not insecure, but it is not *documented* secure either. I built a
> version-controlled security baseline that takes a fresh Ubuntu 24.04 server to a measured,
> repeatable hardened state, and I can prove the improvement with an audit."

Show the repository tree — one command:

```bash
tree -L 2 || find . -maxdepth 2 -type d | sort
```

## Minute 1–3 — The "before" evidence

```bash
head -20 evidence/lynis-baseline-console.txt
grep -E 'hardening_index|warning\[\]' ~/evidence/lynis-baseline-report.dat | head
```

> "Baseline hardening index was **X** with **N** warnings. These are the findings I turned into
> controls."

Show the benchmark table: `benchmark/IAC-Linux-Secure-Baseline-v1.0.md`.

> "13 controls, each with a CIS reference, a verification command and a status. I documented what
> I deliberately did not implement and why."

## Minute 3–4 — The plan, before touching anything

```bash
ansible-playbook -i inventory.ini site.yml --check --diff -K
```

> "Check mode: Ansible tells me exactly what it *would* change. Nothing has been modified yet."

Point at two or three `changed:` lines and name the control they implement.

## Minute 4–6 — Apply the baseline

```bash
ansible-playbook -i inventory.ini site.yml -K
```

Narrate what you see. When the recap prints:

> "That is N tasks changed across 9 roles. Every one of them is declarative — I never scripted
> `echo >> file`, I declared the desired state."

## Minute 6–7 — Prove it is hardened

```bash
bash scripts/02-verify-controls.sh
```

> "This is an independent check — it does not trust Ansible's own output. Every line is PASS."

Then three quick spot checks:

```bash
sudo sshd -T | grep -i permitrootlogin
sudo ufw status verbose
sudo stat -c '%a %U:%G %n' /etc/shadow /etc/sudoers
```

Optional drama, 10 seconds:

```bash
ssh root@localhost        # Permission denied
```

## Minute 7–8 — Prove it is idempotent

```bash
ansible-playbook -i inventory.ini site.yml -K
```

> "Second run: `changed=0`. Running it a hundred times leaves the machine in the same state. That
> is what makes this safe to put in a real change-management process."

## Minute 8–9 — The "after" evidence

```bash
cat ~/evidence/lynis-history.txt
```

> "Hardening index went from **X** to **Y**, warnings fell from **N** to **M**."

Show the before/after table from the report. Mention one Lynis suggestion you intentionally left.

## Minute 9–10 — Exceptions and what I would do next

Say this, it is the highest-value 30 seconds of the demo:

> "I did not implement AIDE file-integrity monitoring, custom AppArmor profiles, separate
> partitions, or passwordless-only SSH. In each case the reason is scope or lab usability, not
> ignorance of the control — and for SSH in particular the role refuses to disable password
> authentication unless a key is already deployed, because a benchmark that can lock the
> administrator out is a bad benchmark. With more time I would add AIDE, a CIS Level 2 pass, and
> run the same playbook against a second host to prove fleet consistency."

---

## Questions to be ready for

| Question | Answer |
|---|---|
| Why Ansible and not a shell script? | Idempotency, per-control structure, dry-run (`--check`), and it is the industry tool for Linux configuration management. |
| Why not Terraform? | Terraform provisions infrastructure; this project configures an existing OS. Different layer. |
| Is this CIS certified? | No. It is a custom baseline *informed by* CIS Level 1. Certification is an audit process, not a checklist. |
| Why keep `PasswordAuthentication yes`? | No key infrastructure in the lab, and locking the only admin out would end the project. It is recorded as an exception, and the role enforces a key check before it can be turned off. |
| Why is the hardening index not 100? | Lynis scores things outside scope — file-integrity databases, boot loaders, enterprise logging. I document each gap instead of chasing the number. |
| What happens if a control breaks a service? | The firewall role asserts SSH is allowed before enabling UFW; the SSH template is validated with `sshd -t` before it is written; and the VM snapshot means any run is reversible in one click. |
| How do you know nothing regressed? | `scripts/02-verify-controls.sh` plus a functional test after each role, plus the second run reporting `changed=0`. |

## Failure drill (if something breaks live)

1. Do not debug in front of the audience. Say "let me show you the recorded evidence" and open
   the saved output files.
2. If SSH is gone, switch to the VM console — that is why it stays open.
3. Last resort: revert the `pre-demo` snapshot and say so. Recovering deliberately is a better
   story than pretending nothing happened.
