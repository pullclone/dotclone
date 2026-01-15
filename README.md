
# ❄️ NyxOS — Framework 13 AMD (AI 300 / Strix Point) • Niri on NixOS 25.11

A declarative, modular, and opinionated **NixOS 25.11** configuration built for the **Framework 13 AMD (AI 300 / Strix Point)** laptop.

NyxOS ships a **Desktop Router**: instantly switch between a modern **Noctalia** desktop and a retro-futuristic **Waybar (Aurora)** setup while keeping a *single*, unified backend for theming, keybinds, and shell tooling.

---

## Contents

- [Architecture](#-architecture)
- [Dual-profile system](#-dual-profile-system)
- [Features & tooling](#️-features--tooling)
- [ZRAM & LatencyFleX profiles](#-zram--latencyflex-profiles)
- [Install & configuration](#️-install--configuration)
- [Keybindings (Niri)](#-keybindings-niri)
- [Core package set](#-core-package-set)
- [Performance, testing & monitoring](#-performance-testing--monitoring)
- [Credits](#-credits)

---

## 🏗 Architecture

- **Basis:** NixOS 25.11 + Home Manager (flakes)
- **Compositor:** [Niri](https://github.com/YaLTeR/niri) — scrollable tiling Wayland compositor
- **Theme:** Catppuccin Mocha via **Stylix**
- **Shells:** Fish (primary) + Bash (fallback), unified aliases
- **Kernel:** `linuxPackages_latest` (RDNA 3.5 graphics & NPU support)

---

## 🌗 Dual-profile system

NyxOS provides two distinct desktop “personalities,” switchable in `home-ashy.nix`:

| Feature        | **Noctalia profile**                 | **Waybar (Aurora) profile**        |
|---------------|--------------------------------------|------------------------------------|
| Aesthetic     | Modern, Material You, widget-heavy   | Cyberpunk/Aurora, text-forward     |
| Panel / bar   | Noctalia Shell (Quickshell)          | Waybar (Aurora config)             |
| Launcher      | Fuzzel                               | Wofi                               |
| Terminal      | Kitty                                | Kitty                              |
| Notifications | Mako                                 | Mako                               |

### Switch profiles

Edit `home-ashy.nix`:

```nix
my.desktop.panel = "noctalia";  # or "waybar"
````

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#nyx
```

---


### 🖱️ Hardware & input

* **G502 Lightspeed:** `g502-manager` CLI for hardware profile mapping (no GUI bloat)
* **DualSense:** kernel-level support via `game-devices-udev-rules`
* **Bluetooth:** minimal BlueZ build (stripped of OBEX/Mesh extras)

### ⚡ Performance & latency

* **ZRAM:** multiple compressed-swap profiles, selectable via flake outputs
* **LatencyFleX:** optional Vulkan implicit layer for vendor-agnostic latency reduction
* **Sysctl:** tuned `vm.swappiness`, dirty writeback, and cache pressure

### 🔒 Kernel hardening (defaults)

- `kernel.randomize_va_space=2` enforces full ASLR.
- `kernel.kptr_restrict=2` hides kernel pointers from unprivileged users.
- `kernel.dmesg_restrict=1` restricts kernel logs to privileged users.
  *Tradeoff:* diagnostics/perf tooling may be less informative; temporarily lower these only when debugging.

### ⏱️ Secure time sync

- Chrony is enabled with NTS (Network Time Security) against a default
  set of NTS-capable servers (Cloudflare + Netnod).
- Override servers via `my.security.timeSync.ntsServers = [ "time.example.net" ... ];`
  in `configuration.nix` or a host overlay.
- Verify status at runtime: `chronyc sources -v` (look for `NTS`/`PNTS`)
  and `chronyc tracking`.

### 🔌 USBGuard (declarative policy)

- USBGuard is enabled with a declarative ruleset at `etc/usbguard/rules.conf`
  (deployed to `/etc/usbguard/rules.conf`).
- Generate an initial policy from currently attached devices:

  ```bash
  scripts/usbguard-generate-policy.sh > /tmp/usbguard.rules
  # review/edit, then replace etc/usbguard/rules.conf with the approved rules
  sudo nixos-rebuild switch --flake .#nyx
  ```

- Keep a root shell/TTY/SSH session open when testing to avoid lockout.
- Refine rules before enabling on untrusted ports; `usbguard list-devices`
  helps inspect current devices.

### 🛡️ Systemd hardening

- `DefaultNoNewPrivileges=yes` is set globally via systemd manager
  defaults.
- Override for a specific unit only when necessary:

  ```nix
  systemd.services.my-service.serviceConfig.NoNewPrivileges = lib.mkForce false;
  ```

  Use sparingly—most services should run with `NoNewPrivileges=true`.

### 🔑 Privilege escalation

- `doas` is the supported escalation path; `sudo` is disabled.
- Only the admin user (`ashy` by default) may use `doas`; no persistence
  tokens are issued by default.
- Root login is disabled (including over SSH). For recovery, use a
  console/TTY or boot into a rescue environment and edit
  `configuration.nix` if needed.

### 🤖 AI & development

* **Local AI:** `aichat`, `rocm-smi`, Python data stack
* **Web apps:** isolated Brave instances (Wayland-native)
* **Chat swapper:** `aiswap` for fast model/persona switching

---

## 🗜️ System & LatencyFleX profiles

NyxOS exposes **system profiles** (VM/sysctl/ZRAM/CPU governor) and **LatencyFleX** as flake arguments.
Profiles are selected via `--argstr systemProfile <name>`; LatencyFleX via `--arg latencyflexEnable <bool>`.
Selection happens at flake evaluation time—no runtime toggling.

### System profiles (`--argstr systemProfile …`)

| Profile           | Priority                      | ZRAM              | CPU governor  | Notes                                  |
| ----------------- | ----------------------------- | ----------------- | ------------- | -------------------------------------- |
| `latency`         | interactive responsiveness    | LZ4               | performance   | lower dirty ratios, faster writeback   |
| `balanced` (default) | general desktop           | ZSTD balanced     | schedutil     | sane defaults                          |
| `throughput`      | long-running jobs             | ZSTD balanced     | schedutil     | higher dirty ratios, warmer caches     |
| `battery`         | efficiency/thermals           | ZSTD balanced     | powersave     | gentler writeback + reclaim            |
| `memory-saver`    | fit more in RAM               | ZSTD aggressive   | schedutil     | more compression + higher swappiness   |

### LatencyFleX (`--arg latencyflexEnable …`)

| Value  | Effect              |
| ------ | ------------------- |
| `true` | LatencyFleX ON      |
| `false`| LatencyFleX OFF     |

### Examples

```bash
# Default: balanced + LatencyFleX ON
sudo nixos-rebuild switch --flake .#nyx

# Latency-first
sudo nixos-rebuild switch --flake .#nyx --argstr systemProfile latency

# Throughput-heavy
sudo nixos-rebuild switch --flake .#nyx --argstr systemProfile throughput

# Battery-first with LatencyFleX off
sudo nixos-rebuild switch --flake .#nyx --argstr systemProfile battery --arg latencyflexEnable false
```

#### 🧰 Justfile helpers

```bash
just switch                   # default (balanced + LatencyFleX on)
just switch-balanced          # balanced + LatencyFleX on
just switch-aggressive        # throughput profile
just switch-writeback         # memory-saver profile (configure writeback device if desired)

just switch-latencyflex-on
just switch-latencyflex-off
```

These helpers only pass flake arguments—they do not mutate configuration files or runtime state.

---

### When to use writeback

ZRAM writeback is appropriate on systems with **fast NVMe storage** and workloads that occasionally exceed physical RAM.
It trades a small amount of flash wear for avoiding OOM conditions. Avoid on slow SSDs or HDDs.

---

### ZRAM and `swappiness`

NyxOS defaults to `vm.swappiness=10`, preferring RAM until pressure rises.
Each ZRAM profile sets appropriate swappiness and priority values automatically. Manual tuning is usually unnecessary.

---

## ⚙️ Install & configuration

### Installer Prompts → Answers Fields

| Prompt                                | Answers field                       | Notes |
| ------------------------------------- | ------------------------------------ | ----- |
| Username                              | `userName`                          | Default `ashy`; change after install |
| Hostname                              | `hostName`                          | Default `nyx` |
| Timezone                              | `timeZone`                          | Default `UTC` |
| MAC policy                            | `mac.mode/interface/address`        | `default`/`random`/`stable`/`fixed` |
| Boot mode                             | `boot.mode`                         | `uki` (systemd-boot UKI) or `secureboot` (Lanzaboote) |
| Trust phase                           | `trust.phase`                       | `dev` (no firmware/TPM enforcement) or `enforced` |
| Snapshot policy                       | `snapshots.retention/schedule/prePost/remote.*` | See Snapshot section below |
| Trim policy                           | `storage.trim.*`                    | Weekly fstrim by default; no `discard` mounts |
| Encryption intent                     | `encryption.mode`                   | Intent only; enrollment/manual steps documented |
| Swap intent                           | `swap.mode/sizeGiB`                 | Installer creates swap partition when mode=`partition` |
| System profile                        | `profile.system`                    | `balanced` (default), `latency`, `throughput`, `battery` |
| Containers                            | `my.programs.containers.enable`     | Podman + Distrobox toggle |

### Default user

* **Username:** `ashy`
* **Default password:** `icecream`

Change immediately after install:

```bash
passwd
```

For a declarative hash:

1. `mkpasswd -m sha-512`
2. Set `users.users.ashy.hashedPassword` in `configuration.nix`

### MAC address spoofing

```nix
networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";
```

### Snapshots (btrbk)

- Recommended retention: **7–15** snapshots; default is **11**.
- `retention = -1` → do not configure snapshots.
- `retention = 0`  → explicitly disable snapshots.
- `retention > 0`  → enable btrbk snapshots (exclude `/nix`) and optional pre/post rebuild snapshots.
- A warning is shown if you select retention **>33** (high churn risk).

Remote replication (opt-in):

- Enable only with `snapshots.remote.enable = true` **and** a non-empty `target`.
- Use SSH transport with **ed25519** keys restricted to `btrfs receive` and disable port/agent/X11/PTY forwarding.
- Firewall allowlist on the receiver; encrypt backup storage at rest.
- Log/monitor btrbk runs and alert on failures.

### Boot modes (UKI vs Secure Boot)

- **UKI baseline:** systemd-boot + unified kernel image; simplest path, good for dev.
- **Secure Boot (Lanzaboote):** signed UKI via sbctl/Lanzaboote; requires signing keys and firmware SB enablement when `trust.phase = "enforced"`. In `dev`, readiness is built but firmware/TPM enforcement is not required.

### Trust phase

- **dev (default):** build readiness without requiring firmware SB or TPM. Enrollment (e.g., `systemd-cryptenroll` with TPM+PIN) is manual and optional.
- **enforced:** may require firmware SB and TPM checks; TPM+PIN recommended with passphrase fallback.

---
### Custom scripts

Available system‑wide (terminal + bindings):

* `g502-manager` — manage mouse profiles
* `aichat-swap` — switch AI personalities
* `waybar-cycle-wall` — cycle wallpapers (Waybar profile)
* `extract` — universal archive extractor

---

## ⌨️ Keybindings (Niri)

Bindings are normalized so muscle memory stays consistent across both profiles.

| Keybind          | Action     | Notes                              |
| ---------------- | ---------- | ---------------------------------- |
| `Super + Return` | Terminal   | Kitty                              |
| `Super + A`      | Launcher   | Fuzzel (Noctalia) / Wofi (Waybar)  |
| `Super + Q`      | Close      | Close active window                |
| `Super + W`      | Wallpaper  | Toggle wallpaper / cycler          |
| `Super + P`      | Power      | Noctalia session menu / Wofi power |
| `Super + V`      | Clipboard  | Clipboard history                  |
| `Super + Scroll` | Timeline   | Scroll the Niri timeline           |
| `F23 / F24`      | Mouse      | G502 profile switching             |
| `Print`          | Screenshot | Fullscreen screenshot              |

---

## 📦 Core package set

Grouped roughly by purpose (not exhaustive).

**System & utils**
`git`, `curl`, `wget`, `micro`, `unzip`, `unrar`, `p7zip`, `libnotify`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `udiskie`

**Audio & video**
`pipewire`, `wireplumber`, `pwvucontrol`, `playerctl`, `ffmpeg`, `mpv`, `gstreamer` (full plugins)

**Terminal & CLI**
`kitty`, `alacritty`, `eza`, `bat`, `fzf`, `zoxide`, `starship`, `ripgrep`, `jq`, `fastfetch`, `macchina`, `btop`

**Gaming**
`mangohud`, `latencyflex-vulkan`, `libratbag`

**AI & data**
`python3` (numpy, pandas), `rocmPackages`, `aichat`

---

## ⚡ Performance & monitoring

NyxOS includes layered performance tuning across:

* boot + kernel parameters
* memory (swappiness, cache pressure, dirty writeback)
* Btrfs defaults + maintenance
* network stack sysctls
* service‑level tuning (SDDM, PipeWire, power, NetworkManager)
* monitoring: Netdata + Prometheus Node Exporter (+ optional Grafana)

### Quick validation commands

```bash
# Boot analysis
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain

# Kernel params
cat /proc/cmdline

# Memory tuning
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure

# Filesystem state (Btrfs)
mount | grep btrfs
btrfs filesystem usage /
btrfs filesystem df /

# Network tuning
sysctl net.ipv4.tcp_tw_reuse
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_rmem
```

---

### ⚡ Performance & Monitoring Deep Dive

This configuration includes layered tuning across **boot/kernel**, **memory**, **storage (Btrfs)**, **network**, **service behaviour**, and **observability**. This section is a single reference: what’s tuned, where to look and how to validate.

> *Note:* Some commands below may require installing the tool (`stress-ng`, `iperf3`, `sysstat`, `powertop`, etc.). If a command isn’t available, skip it—your system configuration can still be verified via the kernel/sysctl/service checks.

---

#### 🚀 Boot & Kernel

**What’s tuned (high level):**

* Faster boot via parallel service start-up and reduced timeouts (where configured)
* Kernel command‑line choices for stability/latency characteristics:

  * `nowatchdog`
  * `nmi_watchdog=0`
  * `tsc=reliable`

**Validate & inspect:**

```bash
# Overall boot time and breakdown
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain

# Kernel cmdline
cat /proc/cmdline

# Boot logs (current boot)
journalctl -b
```

**Optional: generate a boot chart**

```bash
systemd-analyze plot > boot.svg
```

---

#### 🧠 Memory Management

**What’s tuned (common knobs):**

* `vm.swappiness=10`
* `vm.vfs_cache_pressure=50`
* Tuned dirty writeback behaviour (`vm.dirty_*`)
* Optional/advanced: HugePages + overcommit policy tuning

**Validate:**

```bash
# Core VM knobs
sysctl vm.swappiness
sysctl vm.vfs_cache_pressure

# Dirty page/writeback knobs (inspect all relevant ones)
sysctl vm.dirty_ratio
sysctl vm.dirty_background_ratio
sysctl vm.dirty_bytes
sysctl vm.dirty_background_bytes
sysctl vm.dirty_expire_centisecs
sysctl vm.dirty_writeback_centisecs

# Live memory view
free -h
vmstat 1
```

**HugePages & THP / explicit HugePages:**

```bash
# Overview
cat /proc/meminfo | grep -i huge

# If explicitly configured:
sysctl vm.nr_hugepages

# Transparent HugePages (THP) policy (if present)
cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
cat /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
```

**Overcommit policy:**

```bash
sysctl vm.overcommit_memory
sysctl vm.overcommit_ratio
```

---

#### 🗜️ ZRAM / Swap Behaviour

**What’s tuned:**

* ZRAM‑enabled swap with selectable algorithm preference (LZ4 vs ZSTD) via flake output
* Each profile sets swap size, `swappiness`, priority and writeback settings

**Validate:**

```bash
# Check swap devices
swapon --show

# Check ZRAM devices (if any)
lsblk | grep -i zram || true

# zramctl if available
zramctl 2>/dev/null || true
```

---

#### 💾 Filesystem & Btrfs

**What’s tuned:**

* Btrfs mount options, typically including:

  * `noatime,nodiratime`
  * `compress=zstd` (or `compress=zstd:3` if set)
  * `space_cache=v2`
  * `ssd`
  * `commit=120`
  * optional: `autodefrag`
  * optional: `thread_pool=4`

**Validate mount options:**

```bash
# Mounted options (quick)
mount | grep btrfs

# More structured view
findmnt / -o TARGET,FSTYPE,OPTIONS
```

**Inspect Btrfs usage / health:**

```bash
btrfs filesystem usage /
btrfs filesystem df /
btrfs device stats /
```

**Maintenance status (if your config uses maintenance tooling):**

```bash
# If present (varies by setup)
systemctl status btrfs-scrub@-.* 2>/dev/null || true
btrfs scrub status / 2>/dev/null || true
```

**Manual maintenance / repair‑style ops (use intentionally):**

```bash
# Start scrub (online check)
sudo btrfs scrub start /

# Balance example (adjust to preference)
sudo btrfs balance start -dusage=80 /

# Defrag (use sparingly; useful for specific workloads)
sudo btrfs filesystem defrag -r -v /
```

---

#### 🌐 Network Stack & Transport Tuning

**What’s tuned (typical targets):**

* Socket backlog / connection handling (`net.core.somaxconn`)
* TCP memory buffers (`net.ipv4.tcp_rmem`, `net.ipv4.tcp_wmem`)
* Optional: TIME_WAIT reuse (`net.ipv4.tcp_tw_reuse`)
* Optional: congestion control (e.g. **BBR**) for throughput/latency

**Validate:**

```bash
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_tw_reuse
sysctl net.ipv4.tcp_rmem
sysctl net.ipv4.tcp_wmem
sysctl net.ipv4.tcp_congestion_control
```

**Quick network state / debugging:**

```bash
nmcli general status
ip addr show
ss -tlnp
```

**Optional: throughput testing**

```bash
# Requires iperf3
iperf3 -c <server>
```

---

#### 💽 I/O Scheduler & Storage Queueing

**What’s tuned (optional):**

* I/O scheduler choice (e.g. **BFQ**) for responsiveness under mixed workloads

**Validate (example NVMe device shown):**

```bash
cat /sys/block/nvme0n1/queue/scheduler
```

---

#### 🧩 Service‑Level Tuning & Operations

This setup emphasises a Wayland‑first desktop and keeps operational checks simple and repeatable.

##### Display manager (SDDM)

```bash
sudo systemctl restart sddm
systemctl status sddm
journalctl -u sddm -b
```

##### Audio (PipeWire)

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
systemctl --user status pipewire wireplumber
pw-top
wpctl status
```

##### NetworkManager

```bash
sudo systemctl restart NetworkManager
systemctl status NetworkManager
journalctl -u NetworkManager -b
```

##### Power profiles

```bash
powerprofilesctl list
powerprofilesctl get
powerprofilesctl set performance
```

##### CPU governor (informational)

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
```

##### Find failed services quickly

```bash
systemctl --failed
```

---

#### 📈 Observability: Netdata, Prometheus, Grafana

**Endpoints:**

* Netdata: `http://localhost:19999`
* Node Exporter: `http://localhost:9100/metrics`
* Grafana (optional): `http://localhost:3000`

**Service checks:**

```bash
sudo systemctl status netdata
journalctl -u netdata -f
```

```bash
sudo systemctl status prometheus-node-exporter
curl -s http://localhost:9100/metrics | head
curl -s http://localhost:9100/metrics | grep -i btrfs || true
```

```bash
sudo systemctl status grafana-server
journalctl -u grafana-server -f
```

---

#### 🧪 Benchmarking & Sanity Tests (Optional)

These help confirm the system *behaves* like the tuning suggests.

**CPU:**

```bash
# Requires stress-ng
stress-ng --cpu 4 --timeout 30s --metrics-brief
lscpu
```

**Memory:**

```bash
# Requires stress-ng
stress-ng --vm 2 --vm-bytes 1G --timeout 30s --metrics-brief
cat /proc/meminfo | head
```

**Disk (be careful—writes data):**

```bash
# Simple direct‑write test (creates a 1 GiB file)
dd if=/dev/zero of=testfile bs=1G count=1 oflag=direct status=progress
rm -f testfile
```

**Network:**

```bash
# Latency / DNS quick checks
ping -c 10 google.com
time dig google.com
```

---

#### 🧰 Everyday “Ops” Shortlist

**Quick health snapshot:**

```bash
systemd-analyze
free -h
df -h
systemctl --failed
journalctl -p 3 -xb
```

**Rollback if needed:**

```bash
sudo nixos-rollback
nixos-rollback --list
```

**Garbage collection / store maintenance:**

```bash
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

**Btrfs periodic care (as-needed):**

```bash
sudo btrfs scrub start /
sudo btrfs balance start -dusage=80 /
```

---

## 🎨 Credits

* **Aurora Theme:** based on [Aurora Dotfiles by flickowoa](https://github.com/flickowoa/dotfiles/tree/aurora), ported/adapted to Nix and Niri workspaces
* **Catppuccin:** system palette by [Catppuccin](https://github.com/catppuccin/catppuccin)
* **Niri:** compositor by [YaLTeR](https://github.com/YaLTeR/niri)

```

---
