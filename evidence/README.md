# Evidence folder

Curated proof for the report. Raw audit output is generated on the VM in `~/evidence`
(git-ignored); copy the small, meaningful files here and commit them.

## Naming convention

| File | Produced by | Keep in Git? |
|---|---|---|
| `baseline-<host>-<timestamp>.txt` | `scripts/00-collect-baseline.sh` | yes (it is text, ~40 KB) |
| `lynis-baseline-console.txt` | `scripts/01-lynis-audit.sh baseline` | yes |
| `lynis-final-console.txt` | `scripts/01-lynis-audit.sh final` | yes |
| `lynis-history.txt` | `scripts/01-lynis-audit.sh` (appends) | yes |
| `lynis-*-report.dat` | Lynis | no — large, git-ignored |
| `lynis-*.log` | Lynis | no — large, git-ignored |
| `verify-controls-<date>.txt` | `scripts/02-verify-controls.sh` | yes |
| `check-mode-<date>.txt` | `ansible-playbook --check --diff` | yes |
| `screenshots/*.png` | you | yes |

## Before / after table (fill this in for the report)

| Metric | Before | After | Change |
|---|---|---|---|
| Lynis hardening index | | | |
| Warnings | | | |
| Suggestions | | | |
| Pending package updates | | | |
| Enabled services | | | |
| Listening ports | | | |
| SSH `PermitRootLogin` | | | |
| UFW status | | | |
| auditd rules loaded | | | |
| `changed` count on second playbook run | n/a | | must be 0 |

## Capture commands

```bash
bash scripts/00-collect-baseline.sh ~/evidence
bash scripts/01-lynis-audit.sh baseline ~/evidence
bash scripts/02-verify-controls.sh | tee ~/evidence/verify-controls-$(date +%F).txt
ansible-playbook -i inventory.ini site.yml --check --diff -K | tee ~/evidence/check-mode-$(date +%F).txt
bash scripts/01-lynis-audit.sh final ~/evidence
```

Screenshots worth taking (VirtualBox: **View → Take Screenshot**, or Windows `Win+Shift+S`):

1. `sudo ufw status verbose`
2. `sudo sshd -T | grep -Ei 'permitrootlogin|maxauthtries'`
3. `sudo auditctl -l`
4. `stat -c '%a %U:%G %n'` on the sensitive files
5. The Ansible recap line showing `changed=0` on the second run
6. `lynis-history.txt` showing the index jump
