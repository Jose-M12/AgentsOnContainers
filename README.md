# ContainersAgents: persistent rootless YOLO environments

This controller maintains exactly two long-lived CLI development containers:

- `containers-agent-debian`
- `containers-agent-fedora`

Both run as the non-root `node` user and provide passwordless `sudo` **inside a
rootless Podman user namespace**. Debian is the no-argument default.

## Daily command

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh shell
```

This resolves to:

- Debian
- automatic AC/battery limits
- `/home/jose/Scripts/Development/ContainersAgents/projects/container-agent-test`
  mounted at `/workspace`
- `state/debian/home` mounted at `/home/node`

The command starts the persistent Debian container, opens Bash, and stops the
container when Bash exits. It does **not** remove the container. Packages
installed with `sudo apt install` remain for the next session.

Fedora:

```bash
./agents.sh shell fedora
```

Battery profile explicitly:

```bash
./agents.sh shell battery
./agents.sh shell fedora battery
```

Leave a container running after leaving Bash:

```bash
./agents.sh shell --keep-running
```

## Persistence model

| Location | Backing storage | Survives stop/start | Survives reset |
|---|---|---:|---:|
| `/workspace` | `projects/container-agent-test` | Yes | Yes |
| `/home/node` | `state/<distro>/home` | Yes | Yes |
| `/etc`, `/usr`, `/var` | Persistent container writable layer | Yes | No |
| Base files | Debian/Fedora image | Yes | Recreated from image |

`exit` stops the container by default. It no longer destroys the writable layer.

## Passwordless sudo

Inside either container:

```bash
sudo -n true
sudo apt-get update              # Debian
sudo apt-get install <package>

sudo dnf install <package>       # Fedora
```

This is container root, not Ubuntu host root. The controller does not mount the
host root filesystem, host home, or Podman socket. The mounted project and
agent home are intentionally writable and remain exposed to the agent.

## First build

```bash
./agents.sh disable-background
unset DOCKER_HOST
./agents.sh doctor
./agents.sh build all
./agents.sh image-info all
```

## Lifecycle commands

```bash
./agents.sh shell                 # Start Debian, enter, stop on exit
./agents.sh start fedora          # Start Fedora and leave it running
./agents.sh exec fedora           # Enter an already-running Fedora container
./agents.sh stop all              # Stop both; preserve them
./agents.sh status
./agents.sh off-check
```

Reset discards a container's writable operating-system layer, including
packages installed interactively. It preserves `/workspace` and `/home/node`:

```bash
./agents.sh reset debian --yes
```

Rebuild updates the image and resets the selected container:

```bash
./agents.sh rebuild debian --yes
./agents.sh rebuild all --yes
```

## Configuration

Edit `containers-agents.conf` to change the default project, distribution,
power profile, limits, or automatic stop behavior.

## VS Code

Start the desired container and attach rather than creating a second Dev
Container:

```bash
./agents.sh start debian
```

In VS Code run **Dev Containers: Attach to Running Container...**, select
`containers-agent-debian`, and open `/workspace`.

Stop it when finished:

```bash
./agents.sh stop debian
./agents.sh off-check
```

## Documentation

- `docs/TECHNICAL_ARCHITECTURE.md` — detailed technical and architectural report
- `docs/SETUP_AND_USAGE.md` — full setup and usage (Ubuntu and macOS)
- `docs/CHEATSHEET.md` — daily commands after setup

Older drafts and superseded reports live under `archive/docs-outdated/`.
