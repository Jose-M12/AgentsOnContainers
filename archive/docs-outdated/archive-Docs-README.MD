# ContainersAgents

A manual, rootless Podman environment for terminal-based coding agents and VS Code Dev Containers.

The controller is intended for:

- Claude-, Codex-, Grok-, Aider-, and similar terminal/CLI agents.
- Project-specific development shells.
- Explicit start and stop behavior with no permanently enabled Podman API service.
- Low battery impact when inactive.
- Two CLI-only Linux image profiles: Debian and Fedora.

## Recommended image policy

- **Debian is the default:** Node.js 24 LTS on Debian 13 `trixie-slim`. It is the primary compatibility environment for Node- and Python-based agent CLIs.
- **Fedora is secondary:** Fedora Minimal 44 with Node.js and Python installed from Fedora repositories. It is useful for newer RPM/DNF toolchains and Fedora-specific validation.

Both images may remain installed simultaneously. A stopped image consumes disk space only; it does not consume CPU or RAM.

See [Container image profiles](docs/CONTAINER_IMAGES.md) for the full comparison.

## Documentation

- [Technical and architectural report](docs/TECHNICAL_ARCHITECTURE.md)
- [Full setup and usage report](docs/SETUP_AND_USAGE.md)
- [Container image profiles](docs/CONTAINER_IMAGES.md)

## Design guarantees

- No enabled `podman.socket` is required.
- No `loginctl` lingering is required.
- The host home directory is never mounted as a whole.
- The Podman socket is never mounted into an agent container.
- Only the selected project and one distribution-specific state directory are writable host mounts.
- Foreground shells are disposable and removed when they exit.
- CPU quota is automatically reduced when battery power is detected.
- `off-check` fails while any rootless Podman container, user/rootful Podman API unit, or user lingering remains active.
- `deep-off` optionally stops Podmanâ€™s rootless namespace pause process after the normal off-state check passes.
- Debian and Fedora use separate persistent homes to prevent incompatible Python environments or native Node modules from being shared.

## Intended installation path

```text
/home/jose/Scripts/Development/ContainersAgents
```

## First installation

```bash
mkdir -p /home/jose/Scripts/Development
cp -a ContainersAgents-template \
  /home/jose/Scripts/Development/ContainersAgents

cd /home/jose/Scripts/Development/ContainersAgents
chmod +x agentctl agents.sh

sudo apt update
sudo apt install -y podman uidmap

./agents.sh disable-background
./agents.sh doctor
./agents.sh build all
./agents.sh image-info all
```

## Fastest safe start

Debian, automatic AC/battery selection:

```bash
./agents.sh shell /absolute/path/to/project
```

Fedora, forced battery profile:

```bash
./agents.sh shell /absolute/path/to/project fedora battery
```

Exit the foreground shell normally:

```bash
exit
```

The disposable container is removed automatically.

## Definitive shutdown

```bash
./agents.sh down --all
./agents.sh disable-background
unset DOCKER_HOST
./agents.sh off-check
```

For the deepest rootless shutdown, after the normal sequence succeeds:

```bash
./agents.sh deep-off
```

`deep-off` runs `podman system migrate` as its final Podman command. Do not issue another Podman command afterward if the namespace pause process must remain stopped; any later Podman operation may recreate it.

Do not use `podman system reset` as routine setup or maintenance. Do not schedule blanket `podman system prune --volumes` commands.
