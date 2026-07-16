# ContainersAgents cheatsheet

Quick reference **after** setup and first image build.  
Full install: `docs/SETUP_AND_USAGE.md` · Design: `docs/TECHNICAL_ARCHITECTURE.md`

```bash
cd /path/to/ContainersAgents
```

---

## Daily

| Goal | Command |
|---|---|
| Debian shell (default) | `./agents.sh shell` |
| Fedora shell | `./agents.sh shell fedora` |
| Battery limits | `./agents.sh shell battery` |
| Fedora + battery | `./agents.sh shell fedora battery` |
| Balanced / AC | `./agents.sh shell balanced` · `./agents.sh shell ac` |
| Leave container running after exit | `./agents.sh shell --keep-running` |

Default `shell` behavior: start → interactive Bash → **stop** (do not remove).

---

## Keep running / multi-terminal / VS Code

| Goal | Command |
|---|---|
| Start and detach | `./agents.sh start debian` · `./agents.sh start fedora` |
| Enter running container | `./agents.sh exec debian` · `./agents.sh exec fedora` |
| Stop one / both | `./agents.sh stop debian` · `./agents.sh stop all` |
| Status | `./agents.sh status` |

VS Code: start container → **Dev Containers: Attach to Running Container...** → open `/workspace` → stop when done.

---

## Inside the container

| Goal | Debian | Fedora |
|---|---|---|
| Who am I / where | `whoami` · `pwd` → `node` · `/workspace` | same |
| Passwordless sudo check | `sudo -n true` | `sudo -n true` |
| Install package | `sudo apt-get update && sudo apt-get install -y NAME` | `sudo dnf install -y NAME` |
| Upgrade OS packages | `sudo apt-get upgrade` | `sudo dnf upgrade` |
| Agents | `codex` · `claude` | `codex` · `claude` |
| Update Codex (npm) | `sudo npm install -g @openai/codex@latest` | same |
| Update Claude Code | `sudo apt-get install --only-upgrade claude-code` | `sudo dnf upgrade claude-code` |

Credentials live in `/home/node` (host: `state/<distro>/home`). Authenticate once per distro.

---

## Images and rebuild

| Goal | Command |
|---|---|
| Build | `./agents.sh build all` · `./agents.sh build debian` · `./agents.sh build fedora` |
| Versions / sudo status | `./agents.sh image-info all` |
| Image list / size | `./agents.sh images` |
| Drop OS layer only | `./agents.sh reset debian --yes` |
| New image + drop OS layer | `./agents.sh rebuild fedora --yes` |
| Rebuild both | `./agents.sh rebuild all --yes` |

`reset` / `rebuild` keep `/workspace` and `/home/node`. They remove packages installed only in the writable OS layer.

---

## Config and paths

| Goal | Command |
|---|---|
| Show project path | `./agents.sh project-path` |
| Show effective config | `./agents.sh config` |
| Edit defaults | `containers-agents.conf` |

| Mount | Host | Container |
|---|---|---|
| Project | `projects/container-agent-test` (or config) | `/workspace` |
| Debian home | `state/debian/home` | `/home/node` |
| Fedora home | `state/fedora/home` | `/home/node` |

---

## Host health (especially Ubuntu)

| Goal | Command |
|---|---|
| Diagnose | `./agents.sh doctor` |
| Disable rootless socket / lingering | `./agents.sh disable-background` · `unset DOCKER_HOST` |
| Verify everything stopped | `./agents.sh stop all` · `./agents.sh off-check` |
| Deeper off cleanup | `./agents.sh deep-off` |

macOS: after `stop all`, stop the Podman Machine if you want the VM idle (`podman machine stop` or Podman Desktop).

---

## Persistence at a glance

| What | Survives `stop` / shell exit? | Survives `reset` / `rebuild`? |
|---|---|---|
| Project files | Yes | Yes |
| Agent home / logins | Yes | Yes |
| `apt` / `dnf` packages in OS layer | Yes | **No** |
| Image baseline tools | Yes | Yes (from new image on rebuild) |

---

## One-liners worth memorizing

```bash
./agents.sh shell                          # daily Debian
./agents.sh shell fedora battery           # Fedora, low ceiling
./agents.sh start debian && ./agents.sh exec debian
./agents.sh stop all && ./agents.sh off-check
./agents.sh rebuild fedora --yes           # fix/refresh Fedora image + layer
```

```bash
# inside container
sudo -n true
sudo apt-get install -y tree    # Debian
sudo dnf install -y tree        # Fedora
```
