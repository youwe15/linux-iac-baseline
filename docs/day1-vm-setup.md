# Day 1 — Build the lab from scratch

Everything on this page is done **inside VirtualBox on your laptop**. Expect 60–90 minutes
end to end. Do not start step 9 until steps 1–8 are finished.

---

## 0. What you need

- VirtualBox 7.x installed on Windows
- Ubuntu Server 24.04 LTS ISO (see step 1)
- The `linux-iac-baseline` folder (this repository)
- About 25 GB of free disk space and 4 GB of free RAM

> **Check first:** `VBoxManage --version` in PowerShell. If it is missing, install VirtualBox and
> reboot. If VirtualBox complains about Hyper-V, either disable Hyper-V / Memory Integrity, or use
> VirtualBox 7.1 which can co-exist more gracefully.

## 1. Download the right ISO

Go to <https://releases.ubuntu.com/24.04/> and download
`ubuntu-24.04.x-live-server-amd64.iso` (the current point release, ~2.6 GB).

**Do not use 24.10.** Interim releases get 9 months of support; 24.10 has been end-of-life since
July 2025, so patching and automatic updates — controls IAC-LNX-01 and IAC-LNX-02 — cannot be
demonstrated on it, and `apt update` will start failing.

## 2. How many VMs?

| Mode | VMs | You need this if |
|---|---|---|
| **A. Single VM** | 1 | You want to start today, or the laptop has 8 GB RAM or less |
| **B. Controller + target** | 2 | You want a realistic demo and to prove the playbook works remotely |

Mode B is what I recommend for the final demonstration, but **build Mode A first** and get the
full pipeline working. Converting to Mode B later is a 20-minute job: build one more VM, copy the
repo, change `inventory.ini`.

## 3. Create the VM(s)

VirtualBox → **New**:

| Setting | Target (both modes) | Controller (Mode B only) |
|---|---|---|
| Name | `iac-target` | `iac-controller` |
| Type / Version | Linux / Ubuntu (64-bit) | Linux / Ubuntu (64-bit) |
| RAM | 2048 MB (4096 if you have 16 GB+) | 2048 MB |
| CPUs | 2 | 1–2 |
| Hard disk | 25 GB, VDI, dynamically allocated | 20 GB, VDI |

Then per VM: **Settings → Network**

- **Adapter 1:** NAT — gives internet access for `apt`
- **Adapter 2:** Host-only Adapter → `vboxnet0`

If `vboxnet0` does not exist: **File → Tools → Network Manager → Host-only Networks → Create**,
and accept the defaults (`192.168.56.1/24`, DHCP enabled).

## 4. Install Ubuntu Server

Start the VM, attach the ISO, and follow the installer. The answers that matter:

| Prompt | Answer |
|---|---|
| Language / keyboard | your choice |
| Type of install | **Ubuntu Server** (not the minimized image) |
| Network | leave both adapters on DHCP |
| Proxy / mirror | none / default |
| Storage | use the whole disk, LVM default is fine |
| Your name / server name | your name / `iac-target` (or `iac-controller`) |
| Username | `student` — **remember this**, it goes into `inventory.ini` |
| Ubuntu Pro | skip for now |
| **SSH setup** | ☑ **Install OpenSSH server** |
| Featured server snaps | install **none** (press Done with nothing selected) |

Reboot when prompted, remove the ISO, and log in at the console.

## 5. First boot: patch, tool up, snapshot

```bash
# on the VM console
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y lynis ansible git vim curl ufw auditd rsyslog logrotate
sudo reboot
```

After the reboot, log in again and **take the snapshot now**:

> VirtualBox → select VM → **Machine → Take Snapshot** → name it `fresh-install`

This snapshot is your reset button. Every experiment from here on is reversible.

Record the starting point immediately:

```bash
ip -4 a
hostnamectl
```

Write down the IP of the host-only adapter (normally `192.168.56.x` on `enp0s8`, or `.101` if DHCP
picked it).

## 6. Networking — make the address predictable

Simplest: keep DHCP and just use whatever `ip -4 a` reports each time.

Optional but nicer for the report — a static host-only address. On Ubuntu Server the installer uses
cloud-init, so disable its network management first:

```bash
sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg >/dev/null <<'EOF'
network: {config: disabled}
EOF
```

Find the host-only interface name, then create the config:

```bash
ip -br link                      # e.g. lo  enp0s3  enp0s8
sudo tee /etc/netplan/99-static.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
      addresses: [192.168.56.20/24]
EOF
sudo chmod 600 /etc/netplan/99-static.yaml
sudo netplan try || sudo netplan apply
ip -4 a show enp0s8
```

Make sure the NAT adapter (`enp0s3`) stays on DHCP so `apt` keeps working.

## 7. SSH from Windows, then keys

From **PowerShell on Windows**:

```powershell
ssh student@192.168.56.20
```

If that works, set up keys so Ansible never needs a password. On the **controller** (or on the
single VM if you are in Mode A):

```bash
ssh-keygen -t ed25519 -C "iac-lab" -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id student@192.168.56.20        # Mode B
ssh student@192.168.56.20 true && echo "key login OK"
```

## 8. Install Ansible and the collections

On the controller / single VM:

```bash
sudo apt install -y ansible
ansible --version
ansible-galaxy collection install -r requirements.yml
```

## 9. Put the project on the machine and run it

From Windows (Mode A: copy into the single VM; Mode B: copy into the controller):

```powershell
scp -r .\linux-iac-baseline student@192.168.56.20:~/
```

Then on the machine that has the repo:

```bash
cd ~/linux-iac-baseline
chmod +x scripts/*.sh

# Mode A
ansible-playbook -i inventory-local.ini site.yml --syntax-check
# Mode B
ansible-playbook -i inventory.ini site.yml --syntax-check

# connectivity check (Mode B)
# ansible -i inventory.ini linux_servers -m ping
```

Collect the "before" evidence **before** changing anything:

```bash
bash scripts/00-collect-baseline.sh ~/evidence
bash scripts/01-lynis-audit.sh baseline ~/evidence
```

Note the hardening index it prints. **That number is your starting score** — write it down.

Preview the changes, then apply them:

```bash
ansible-playbook -i inventory-local.ini site.yml --check --diff -K   # Mode A
ansible-playbook -i inventory.ini       site.yml --check --diff -K   # Mode B
ansible-playbook -i inventory-local.ini site.yml -K                  # apply
```

`-K` asks for your sudo password. Keep the VM console window open the whole time — if UFW or SSH
misbehaves, that is your way back in.

Then verify:

```bash
bash scripts/02-verify-controls.sh
bash scripts/01-lynis-audit.sh final ~/evidence
ansible-playbook -i inventory-local.ini site.yml -K    # second run: expect changed=0
```

## 10. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Permission denied (publickey,password)` | Key not copied: re-run `ssh-copy-id`, or keep `PasswordAuthentication yes` until it works. |
| `Missing sudo password` | Add `-K` to the playbook command. |
| SSH session dies during the firewall role | From the **VM console**: `sudo ufw allow 22/tcp`. Then check that the allow task runs before `state: enabled`. |
| `Failed to connect to the bus` / systemd errors | You are in a container or the wrong console. Run inside the VM, not in WSL against the VM. |
| `apt update` returns 404 on every line | You installed an EOL release. Reinstall Ubuntu 24.04 LTS. |
| Host-only adapter has no `192.168.56.x` | Recreate `vboxnet0` in VirtualBox Network Manager; `sudo dhclient enp0s8` inside the VM. |
| `sshd -T` → `Missing privilege separation directory: /run/sshd` | `sudo mkdir -p /run/sshd && sudo systemctl restart ssh`. |
| `sshd -T` shows the old values | Drop-in not read: check `Include /etc/ssh/sshd_config.d/*.conf` is the **first** line of `/etc/ssh/sshd_config`, then `sudo systemctl reload ssh`. |
| Playbook says `changed=8` on the second run | Something is not idempotent — usually a `command`/`shell` task. Read the recap; fix or mark it `changed_when: false`. |

## 11. Definition of "Day 1 done"

You are done when you can answer yes to all of these:

- [ ] VM installed, patched, snapshot `fresh-install` taken
- [ ] `~/evidence/baseline-*.txt` exists and is readable
- [ ] `~/evidence/lynis-baseline-console.txt` exists and you know the hardening index
- [ ] `ansible-playbook --syntax-check` passes
- [ ] `ansible -m ping` (Mode B) or `ansible-playbook --check` (Mode A) succeeds
- [ ] You have not changed any security setting yet

Next: `docs/week-plan.md`.
