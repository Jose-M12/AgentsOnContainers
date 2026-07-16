# Full setup and usage guide

This guide installs and operates **ContainersAgents**: two persistent rootless
Podman environments (Debian default, Fedora secondary) with passwordless
container `sudo`, a shared project mount at `/workspace`, and per-distro agent
homes under `state/`.

| Host | Support level |
|---|---|
| **Ubuntu 24.04 LTS** (or similar Debian-based desktop) | Primary — fully exercised path |
| **macOS** (Apple Silicon or Intel) with Podman Machine / Podman Desktop | Supported with the notes in §4 |

Run the controller as your normal user, **not** with `sudo`.

---

## 1. What you get after setup

| Item | Value |
|---|---|
| Containers | `containers-agent-debian`, `containers-agent-fedora` |
| Default entry | `./agents.sh shell` → Debian, auto power, stop-on-exit |
| Project mount | configured project → `/workspace` |
| Agent homes | `state/debian/home`, `state/fedora/home` → `/home/node` |
| Images | `localhost/containers-agents:debian-node24-yolo`, `…:fedora44-yolo` |

Packages installed with `sudo apt` / `sudo dnf` survive stop and shell exit.
They are discarded only by `reset` or `rebuild`. Agent credentials and the
project tree survive those as well.

---

## 2. Prerequisites

### Shared

- Internet access for image pulls and first builds
- A project directory writable by your user
- Enough disk for two images plus writable layers (several GB)

### Ubuntu

- Ubuntu 24.04 LTS recommended
- Ability to install packages with host `sudo` once (`podman`, `uidmap`)
- Rootless Podman working for your user

### macOS

- macOS with Homebrew recommended
- **Podman Desktop** and/or `podman` CLI with a running **Podman Machine**
- Note: containers run in a Linux VM; paths and performance differ from bare-metal Linux

---

## 3. Install the repository

Choose a stable location. Examples:

```bash
# Ubuntu example path used in this tree
mkdir -p ~/Scripts/Development
# or
mkdir -p ~/Developer
```

### 3.1 From a git checkout (typical)

```bash
cd ~/Scripts/Development   # or your preferred parent directory
# clone or copy ContainersAgents into this directory
cd ContainersAgents
chmod +x agentctl agents.sh install-update.sh extras/*.sh
```

### 3.2 From a release archive

```bash
tar -xzf ContainersAgents-Persistent-YOLO.tar.gz -C /tmp
# If the archive includes install-update.sh and you already have a tree:
# /tmp/.../install-update.sh --yes
# Otherwise copy the extracted tree into place, then:
cd /path/to/ContainersAgents
chmod +x agentctl agents.sh install-update.sh extras/*.sh
```

### 3.3 Expected layout

```text
ContainersAgents/
├── agents.sh
├── agentctl
├── Containerfile.debian
├── Containerfile.fedora
├── containers-agents.conf
├── install-update.sh
├── README.md
├── docs/
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── SETUP_AND_USAGE.md
│   └── CHEATSHEET.md
├── extras/
├── projects/container-agent-test/
├── state/debian/home/
├── state/fedora/home/
└── templates/
```

Optional: edit `containers-agents.conf` to change `DEFAULT_PROJECT`, power
ceilings, or `STOP_OTHER_DISTRO_ON_START` before first use.

---

## 4. Install Podman on the host

### 4.1 Ubuntu

```bash
sudo apt update
sudo apt install -y podman uidmap
```

Do **not** enable a permanent Podman API socket for this design.

From the repo:

```bash
cd /path/to/ContainersAgents
./agents.sh disable-background
unset DOCKER_HOST
```

If a shell startup file still exports `DOCKER_HOST` to a Podman socket, remove
that line manually when the controller reports it.

Confirm rootless identity mapping is available:

```bash
podman info
id
grep "^$USER:" /etc/subuid /etc/subgid
```

If `subuid` / `subgid` entries are missing, add them (example for UID ranges —
adjust if your admin policy differs):

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
```

Log out and back in after changing subordinate IDs.

### 4.2 macOS

**Option A — Podman Desktop (recommended for most users)**

1. Install [Podman Desktop](https://podman-desktop.io/).
2. Create and start a Podman Machine from the UI.
3. Confirm the CLI talks to the machine:

```bash
podman version
podman info
```

**Option B — Homebrew CLI**

```bash
brew install podman
podman machine init
podman machine start
podman info
```

macOS notes specific to this controller:

| Topic | Behavior |
|---|---|
| Power `auto` | Linux `/sys/class/power_supply` is not available on the Mac host; `auto` typically behaves like **AC**. Prefer explicit `battery` / `balanced` / `ac` if you care. |
| `disable-background` | Uses `systemctl --user` / `loginctl` patterns aimed at Linux. On macOS, manage Podman Machine start/stop yourself; do not leave an unused machine running if battery matters. |
| Paths | Prefer a path without spaces. Project and state live on the Mac filesystem and are bind-mounted into the Linux VM by Podman. |
| Performance | File I/O on bind mounts can be slower than on bare-metal Linux. Keep large caches inside the container writable layer or agent home when possible. |
| Architecture | On Apple Silicon, prefer `arm64` images/bases; the supplied Containerfiles track multi-arch upstream bases when available. |

---

## 5. Diagnose the host

```bash
cd /path/to/ContainersAgents
./agents.sh doctor
```

Review Podman version, rootless status, storage driver, runtime, cgroup
version, and whether local images already exist.

On Ubuntu, also run:

```bash
./agents.sh disable-background
unset DOCKER_HOST
```

---

## 6. Build the images

First build downloads bases and agent packages; allow several minutes and a
stable network.

```bash
./agents.sh build all
# or only one profile:
./agents.sh build debian
./agents.sh build fedora
```

Verify:

```bash
./agents.sh image-info all
./agents.sh images
```

Expected highlights:

- Debian: Debian GNU/Linux, Node 24.x, Codex, Claude Code, `sudo: passwordless-enabled`
- Fedora: Fedora Linux 44, Node from Fedora repos, Codex, Claude Code, `sudo: passwordless-enabled`

Rebuilds use the **current** host UID/GID. Rebuild both images if you move the
tree to another account with a different UID.

---

## 7. First interactive sessions

### 7.1 Debian (default)

```bash
./agents.sh shell
```

Inside the container:

```bash
pwd                 # /workspace
whoami              # node
cat /etc/os-release
sudo -n true        # must succeed with no password
codex --version
claude --version
```

Install a package and confirm persistence:

```bash
sudo apt-get update
sudo apt-get install -y tree
exit
./agents.sh shell
tree --version      # still present
```

### 7.2 Fedora

```bash
./agents.sh shell fedora
sudo -n true
sudo dnf install -y tree
exit
./agents.sh shell fedora
tree --version
```

### 7.3 Power profiles

```bash
./agents.sh shell battery
./agents.sh shell balanced
./agents.sh shell ac
./agents.sh shell fedora battery
```

With no profile argument, `auto` selects AC vs battery on Linux hosts that
expose power sysfs (see macOS note in §4.2).

---

## 8. Keep-running and multi-terminal use

```bash
./agents.sh start debian
./agents.sh exec debian
# another terminal:
./agents.sh exec debian
```

Or leave a shell session running after exit:

```bash
./agents.sh shell --keep-running
```

Stop later:

```bash
./agents.sh stop debian
# or
./agents.sh stop all
```

By default, starting one distro stops the other so both do not edit the shared
project at once (`STOP_OTHER_DISTRO_ON_START`).

---

## 9. Agent authentication

Inside **each** distro you plan to use:

```bash
codex
claude
```

Credentials and settings land under the mounted `/home/node` (`state/<distro>/home`)
and survive `reset` / `rebuild`. Debian and Fedora homes are separate; log in on
both if you use both.

Never put tokens in a Containerfile or image-build script.

---

## 10. VS Code attach workflow

```bash
./agents.sh start debian    # or fedora
```

In VS Code:

1. **Dev Containers: Attach to Running Container...**
2. Select `containers-agent-debian` or `containers-agent-fedora`
3. Open `/workspace`

When finished:

```bash
./agents.sh stop debian
./agents.sh off-check       # Linux off-state verification
```

This attaches to the **same** persistent container used by the terminal.

---

## 11. Updates

### Packages and agents inside a living container

```bash
# Debian
sudo apt-get update && sudo apt-get upgrade
sudo npm install -g @openai/codex@latest
sudo apt-get install --only-upgrade claude-code

# Fedora
sudo dnf upgrade
sudo npm install -g @openai/codex@latest
sudo dnf upgrade claude-code
```

### Reproducible baseline (image rebuild)

Edit the Containerfile if needed, then:

```bash
./agents.sh rebuild debian --yes
# or
./agents.sh rebuild all --yes
```

This rebuilds the image and removes the selected persistent writable layer.
`/workspace` and `/home/node` are preserved.

### Controller files only (existing install)

If you received a newer archive of the controller:

```bash
/path/to/extracted/install-update.sh --yes
cd /path/to/ContainersAgents
./agents.sh doctor
./agents.sh build all   # only if images/Containerfiles changed
```

`install-update.sh` preserves `state/` and `projects/`.

---

## 12. Recovery

Broken OS layer (bad package experiment):

```bash
./agents.sh reset debian --yes
./agents.sh shell
```

Refresh image and drop OS layer:

```bash
./agents.sh rebuild fedora --yes
./agents.sh shell fedora
```

Legacy multi-image / old named containers:

```bash
./agents.sh migrate-legacy --yes
./agents.sh build all
./agents.sh shell
```

---

## 13. Status and clean shutdown

```bash
./agents.sh status
./agents.sh stop all
./agents.sh off-check
```

On Ubuntu, `off-check` allows **stopped** persistent containers but fails if any
Podman container is still running, a rootless API socket unit is active/enabled,
or user lingering is enabled.

Optional deeper cleanup after a clean off-check:

```bash
./agents.sh deep-off
```

On macOS, stop agent containers with `./agents.sh stop all`, then stop the
Podman Machine from Podman Desktop or `podman machine stop` when you want the
VM idle.

---

## 14. Configuration reference

Edit `containers-agents.conf`:

```bash
DEFAULT_DISTRO="debian"
DEFAULT_PROFILE="auto"
DEFAULT_PROJECT="$ROOT_DIR/projects/container-agent-test"
AUTO_STOP_AFTER_SHELL="1"
STOP_OTHER_DISTRO_ON_START="1"
BATTERY_CPUS="4"
BATTERY_MEMORY="10g"
BALANCED_CPUS="8"
BALANCED_MEMORY="16g"
AC_CPUS="12"
AC_MEMORY="22g"
SHM_SIZE="1g"
PIDS_LIMIT="4096"
```

Print the effective config from the controller:

```bash
./agents.sh config
./agents.sh project-path
```

---

## 15. Troubleshooting

| Symptom | Likely cause | What to try |
|---|---|---|
| `podman: command not found` | Host packages incomplete | Ubuntu: install `podman uidmap`. macOS: install Podman Desktop / `brew install podman` and start the machine. |
| Rootless errors / ID mapping | Missing subuid/subgid (Linux) | Add subordinate IDs; re-login. |
| `DOCKER_HOST` points at a socket | Shell env forces API mode | `unset DOCKER_HOST`; remove from `~/.bashrc` / `~/.zshrc`. |
| Fedora `sudo` PAM / password required | Old image without shadow mode fix | `./agents.sh rebuild fedora --yes` (current Containerfile sets shadow/gshadow to `0400`). |
| `sudo: unavailable` in `image-info` | Image build incomplete or old | Rebuild the affected distro. |
| crun `update --resources` / missing status file | Limit update race on some Podman/crun versions | Warning only if the container still starts; creation-time limits remain. |
| Project files owned by wrong user | Image built as different UID | Rebuild images as the user who owns the project. |
| macOS battery profile ignored | `auto` cannot see Linux power sysfs | Pass `battery` explicitly. |
| VS Code opens a different environment | Generated Dev Container instead of attach | Use **Attach to Running Container** after `./agents.sh start`. |

---

## 16. Security reminders

- Passwordless sudo is **container-local**, not host root.
- The agent can fully control `/workspace` and its `/home/node`.
- Treat `state/*/home` as secret storage; it is gitignored.
- Do not mount the Podman socket into agent containers.
- Prefer `off-check` (Linux) or stopping the Podman Machine (macOS) when idle.

For deeper design detail, see `docs/TECHNICAL_ARCHITECTURE.md`.  
For day-to-day commands, see `docs/CHEATSHEET.md`.
