# ContainersAgents

A manual, rootless Podman controller for terminal-based coding agents and VS Code Dev Containers.

## Design goals

- No enabled Podman socket.
- No `loginctl` lingering.
- No host `$HOME` mount and no container-engine socket mounted into an agent.
- Only the selected project and this controller's isolated `state/home` are writable.
- Disposable foreground shell by default.
- CPU quota is automatically reduced on battery power.
- Explicit `down` and `off-check` commands; `off-check` also fails if any unrelated Podman container is still running.

## Install into the intended location

```bash
mkdir -p /home/jose/Scripts/Development
cp -a ContainersAgents-template /home/jose/Scripts/Development/ContainersAgents
cd /home/jose/Scripts/Development/ContainersAgents
chmod +x agentctl
```

## One-time preparation

```bash
sudo apt update
sudo apt install -y podman uidmap

./agents.sh disable-background
./agents.sh doctor
./agents.sh build
```

Do not run `podman system reset`, do not enable `podman.socket`, and do not enable user lingering for this design.

## Lowest-overhead terminal session

```bash
./agents.sh shell /absolute/path/to/project
```

The default `auto` profile uses 4 CPUs on battery and 12 CPUs on AC. The container is removed automatically when the shell exits.

Explicit profiles:

```bash
./agents.sh shell /path/to/project battery
./agents.sh shell /path/to/project balanced
./agents.sh shell /path/to/project ac
```

## Detached terminal session

```bash
./agents.sh up /path/to/project
./agents.sh exec /path/to/project
./agents.sh down /path/to/project
```

## VS Code

Set this once in VS Code settings:

```json
"dev.containers.dockerPath": "podman"
```

Then:

```bash
./agents.sh init-vscode /path/to/project
./agents.sh vscode /path/to/project
```

In VS Code, run **Dev Containers: Reopen in Container**. Closing the related window stops the container. Remove stopped containers and verify the off state with:

```bash
./agents.sh down --all
./agents.sh off-check
```

## Status and shutdown

```bash
./agents.sh status
./agents.sh down --all
./agents.sh disable-background
./agents.sh off-check
```

## Agent credentials

CLI mode persists agent configuration only under:

```text
/home/jose/Scripts/Development/ContainersAgents/state/home
```

VS Code mode uses the same isolated controller directory. Neither mode mounts the host home directory. Keep API keys out of the Containerfile and source tree.

## Cleanup

Do not schedule blanket prune commands. Inspect usage first:

```bash
podman system df
podman ps -a
podman volume ls
```

Delete only resources you recognize. `podman system prune --volumes` can remove unused named volumes, including credential or cache state.
