# Full Setup and Usage Report

**Report date:** 2026-07-12  
**Target path:** `/home/jose/Scripts/Development/ContainersAgents`  
**Runtime:** Rootless Podman, manually invoked

## 1. Scope

This guide installs ContainersAgents at:

```text
/home/jose/Scripts/Development/ContainersAgents
```

It covers:

- Rootless Podman host setup.
- Debian and Fedora image builds.
- Foreground and detached agent sessions.
- VS Code Dev Containers.
- Distribution and power-profile selection.
- Persistent agent configuration.
- Updates, shutdown verification, troubleshooting, cleanup, and removal.

## 2. Prerequisites

Target host:

- Ubuntu 24.04 LTS.
- A normal non-root user account.
- `sudo` access for initial package installation.
- Internet access while building images or installing agent CLIs.
- Projects stored in directories writable by the user.

The controller must be run as the normal user, not with `sudo`.

## 3. Install the repository

### 3.1 Install from the supplied archive

Assuming the archive is in `~/Downloads`:

```bash
mkdir -p /home/jose/Scripts/Development

tar -xzf ~/Downloads/ContainersAgents-Debian-Fedora-CLI.tar.gz \
  -C /home/jose/Scripts/Development

cd /home/jose/Scripts/Development/ContainersAgents
chmod +x agentctl agents.sh
```

The archive is packaged with `ContainersAgents` as its top-level directory.

### 3.2 Install from an extracted template directory

From the directory containing `ContainersAgents-template`:

```bash
mkdir -p /home/jose/Scripts/Development

cp -a ContainersAgents-template \
  /home/jose/Scripts/Development/ContainersAgents

cd /home/jose/Scripts/Development/ContainersAgents
chmod +x agentctl agents.sh
```

Expected layout:

```text
ContainersAgents/
â”œâ”€â”€ agents.sh
â”œâ”€â”€ agentctl
â”œâ”€â”€ Containerfile.debian
â”œâ”€â”€ Containerfile.fedora
â”œâ”€â”€ README.md
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ CONTAINER_IMAGES.md
â”‚   â”œâ”€â”€ SETUP_AND_USAGE.md
â”‚   â””â”€â”€ TECHNICAL_ARCHITECTURE.md
â”œâ”€â”€ state/
â”‚   â”œâ”€â”€ debian/home/
â”‚   â””â”€â”€ fedora/home/
â””â”€â”€ templates/
    â””â”€â”€ devcontainer.json
```

## 4. Install rootless Podman

```bash
sudo apt update
sudo apt install -y podman uidmap
```

Do not enable the Podman socket for this design.

Remove prior background activation settings:

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh disable-background
unset DOCKER_HOST
```

If a shell startup file contains a persistent `DOCKER_HOST` pointing at a Podman socket, the command prints the filename and line. Remove that line manually.

## 5. Diagnose the host

```bash
./agents.sh doctor
```

Review:

- Podman version.
- Rootless status.
- Storage driver.
- OCI runtime.
- Cgroup version.
- Podman socket/service state.
- User lingering state.
- Whether each local image exists.

A warning about Podman versions below 5 concerns VS Code compatibility. CLI mode can still be tested independently.

## 6. Build the images

Build both profiles:

```bash
./agents.sh build all
```

Build only Debian:

```bash
./agents.sh build debian
```

Build only Fedora:

```bash
./agents.sh build fedora
```

A build is an explicitly requested network- and CPU-intensive operation. Nothing rebuilds automatically in the background.

The build uses the current host UID/GID. Rebuild both images if the repository is moved to a different account with a different UID/GID.

## 7. Verify built versions and sizes

```bash
./agents.sh image-info all
./agents.sh images
```

`image-info` prints the effective operating system, Node.js, npm, Python, and Git versions from each image.

`images` prints local image metadata and size. Both images may remain installed without consuming runtime CPU or RAM.

## 8. Command option model

The default distribution is Debian. The default power profile is `auto`.

Runtime option order is flexible:

```bash
./agents.sh shell /path/to/project fedora battery
./agents.sh shell /path/to/project battery fedora
```

Equivalent explicit option syntax is also accepted:

```bash
./agents.sh shell /path/to/project \
  --distro=fedora \
  --profile=battery
```

Set process-wide defaults when useful:

```bash
export CONTAINERS_AGENTS_DISTRO=fedora
export CONTAINERS_AGENTS_PROFILE=battery
```

Remove them later with:

```bash
unset CONTAINERS_AGENTS_DISTRO CONTAINERS_AGENTS_PROFILE
```

## 9. Foreground disposable sessions

### 9.1 Default Debian session

```bash
./agents.sh shell /absolute/path/to/project
```

The controller:

1. Resolves the absolute project path.
2. Selects Debian.
3. Detects AC or battery power.
4. Builds the Debian image if missing.
5. Mounts the project at `/workspace`.
6. Mounts `state/debian/home` at `/home/node`.
7. Starts an interactive login shell.
8. Removes the container automatically when the shell exits.

### 9.2 Fedora session

```bash
./agents.sh shell /absolute/path/to/project fedora
```

Fedora uses:

```text
state/fedora/home
```

### 9.3 Battery-constrained session

```bash
./agents.sh shell /absolute/path/to/project debian battery
```

### 9.4 Balanced session

```bash
./agents.sh shell /absolute/path/to/project debian balanced
```

### 9.5 AC session

```bash
./agents.sh shell /absolute/path/to/project fedora ac
```

### 9.6 Exit

Inside the container:

```bash
exit
```

Because foreground mode uses `--rm`, the container is deleted after exit.

## 10. Running an agent CLI

Inside the container, `/workspace` is the selected project and `$HOME` is the isolated distribution-specific home.

Install an npm-distributed CLI using its current official instructions. Global npm installs are redirected to:

```text
/home/node/.npm-global
```

Example package-manager pattern:

```bash
npm install -g OFFICIAL_PACKAGE_NAME
```

Install a Python CLI in user scope:

```bash
python3 -m pip install --user OFFICIAL_PACKAGE_NAME
```

Prefer a project virtual environment for project-specific Python dependencies:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
```

### 10.1 Codex CLI

The current official Linux installer can be run inside either profile:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex
```

The installer writes into the isolated container home rather than the host home. Re-run the same official installer when you intentionally want to update Codex.

### 10.2 Claude Code

The current official native installer supports Linux. For the more conservative stable channel:

```bash
curl -fsSL https://claude.ai/install.sh | bash -s stable
claude --version
claude
```

Claude's native installation may check for and download updates while Claude is running. This does not create a persistent host service, but users who require manual-only updates can add the following to the selected distribution's isolated `.bashrc`:

```bash
export DISABLE_AUTOUPDATER=1
```

An npm-based installation is also compatible with the Debian Node 24 profile:

```bash
npm install -g @anthropic-ai/claude-code
```

Do not use `sudo npm install -g`; the image already redirects global npm installation into `/home/node/.npm-global`.

### 10.3 Grok and other agents

The template intentionally does not hard-code an unverified Grok CLI package name. Install xAI/Grok tooling only from current official xAI documentation, then verify the executable and version inside the container.

Vendor commands and package names can change. Re-check official documentation before a fresh installation or major upgrade.

## 11. Credentials and login state

The most practical method is to run the agent's own login command inside the selected container. Its files persist under that distribution's state directory.

Debian state:

```text
/home/jose/Scripts/Development/ContainersAgents/state/debian/home
```

Fedora state:

```text
/home/jose/Scripts/Development/ContainersAgents/state/fedora/home
```

Protect the repository directory with normal user-only permissions. The controller creates the home directories with mode `700`.

For a temporary API key that should not be written to shell history:

```bash
read -rsp 'API key: ' API_KEY
printf '\n'
export API_KEY
```

Use the environment-variable name required by the selected CLI. Unset it before leaving when appropriate:

```bash
unset API_KEY
```

Do not put secrets in:

- Either Containerfile.
- `.devcontainer/devcontainer.json`.
- Git-tracked files.
- Shell commands saved in project documentation.

## 12. Detached sessions

Use detached mode only when the container must survive terminal disconnection.

Start Debian:

```bash
./agents.sh up /absolute/path/to/project debian auto
```

Enter it:

```bash
./agents.sh exec /absolute/path/to/project debian
```

Start Fedora:

```bash
./agents.sh up /absolute/path/to/project fedora battery
./agents.sh exec /absolute/path/to/project fedora
```

Leave the interactive shell without stopping the container:

```bash
exit
```

Stop and remove every managed container for that project:

```bash
./agents.sh down /absolute/path/to/project
```

Stop only one distribution for the project:

```bash
./agents.sh down /absolute/path/to/project fedora
```

Stop and remove all managed containers:

```bash
./agents.sh down --all
```

## 13. Project concurrency protection

The controller refuses to start a second managed container for the same absolute project path.

For example, this is intentionally rejected while the Debian session is still running:

```bash
./agents.sh up /path/to/project debian
./agents.sh shell /path/to/project fedora
```

Stop the existing runtime first:

```bash
./agents.sh down /path/to/project
```

This prevents simultaneous Debian and Fedora agents from racing over the same source tree.

## 14. VS Code Dev Containers

### 14.1 Install prerequisites

Install VS Code and its Dev Containers extension using your preferred trusted source.

Set this VS Code user setting:

```json
"dev.containers.dockerPath": "podman"
```

No Podman API socket is required.

### 14.2 Generate a Debian configuration

```bash
./agents.sh init-vscode /absolute/path/to/project debian auto
```

The `auto` power state is resolved when the JSON is generated. It does not dynamically change while the container is running.

### 14.3 Generate a Fedora battery configuration

```bash
./agents.sh init-vscode /absolute/path/to/project fedora battery
```

### 14.4 Open VS Code

```bash
./agents.sh vscode /absolute/path/to/project debian auto
```

Then run:

```text
Dev Containers: Reopen in Container
```

### 14.5 Switch an existing project from Debian to Fedora

First close the Dev Container window and remove its stopped container:

```bash
./agents.sh down /absolute/path/to/project
```

Replace the generated configuration while preserving a timestamped backup:

```bash
./agents.sh init-vscode \
  /absolute/path/to/project \
  fedora battery --force
```

Reopen the project:

```bash
./agents.sh vscode /absolute/path/to/project fedora battery
```

### 14.6 Close and remove

Closing the associated VS Code window requests that the container stop. Remove the stopped container and verify shutdown:

```bash
./agents.sh down /absolute/path/to/project
./agents.sh off-check
```

## 15. Resource profiles

| Profile | CPU | RAM | Shared memory |
|---|---:|---:|---:|
| `battery` | 4 | 10 GiB | 512 MiB |
| `balanced` | 8 | 16 GiB | 1 GiB |
| `ac` | 12 | 22 GiB | 1 GiB |
| `auto` | Detects AC/battery | Depends on result | Depends on result |

Override a resource for one invocation:

```bash
CONTAINERS_AGENTS_CPUS=6 \
CONTAINERS_AGENTS_MEMORY=12g \
./agents.sh shell /path/to/project debian battery
```

Resource limits are maxima. Lower CPU quota is the most important control for sustained battery consumption.

## 16. Status and monitoring

Managed container status:

```bash
./agents.sh status
```

All Podman containers:

```bash
podman ps -a
```

Live resource use:

```bash
podman stats
```

Storage use:

```bash
podman system df
```

Do not leave `watch`, `htop`, or `podman stats` running solely for monitoring when battery life matters; they refresh periodically and create their own small workload.

## 17. Definitive shutdown procedure

### 17.1 Normal verified off state

Run:

```bash
cd /home/jose/Scripts/Development/ContainersAgents

./agents.sh down --all
./agents.sh disable-background
unset DOCKER_HOST
./agents.sh off-check
```

A successful final line is:

```text
OFF CHECK PASSED: no rootless container workload or Podman API activation remains.
```

The check fails if:

- A managed rootless container is running.
- Any unrelated rootless Podman container is running.
- The user `podman.socket` or `podman.service` is active.
- The user `podman.socket` is enabled for later activation.
- A rootful system `podman.socket` or `podman.service` is active.
- A rootful system `podman.socket` is enabled for later activation.
- User lingering is enabled or cannot be verified.

The controller disables user-level units automatically but does not alter rootful system units. If the check reports one, inspect it before using the suggested `sudo systemctl` command.

Images and stopped containers do not consume CPU or reserve RAM, so images are allowed to remain installed. `down` removes stopped managed containers when you explicitly run it.

### 17.2 Optional deep off state

Rootless Podman can maintain a namespace pause process even when no application container is running. This is not an agent workload or a continuously polling daemon, but it is still a process.

After the normal `off-check` succeeds, stop that process with:

```bash
./agents.sh deep-off
```

`deep-off` first repeats the normal off-state checks, then runs:

```bash
podman system migrate
```

This must be the final Podman command. Do not run `podman ps`, `podman info`, `off-check`, or another controller command afterward when the objective is to keep the pause process stopped, because a later rootless Podman invocation may recreate it.

## 18. Updating base images

Nothing updates automatically.

Manual refresh:

```bash
./agents.sh down --all
./agents.sh build all
./agents.sh image-info all
```

The manual build pulls the selected base tags and recreates the local images. It does not delete distribution state.

## 19. Updating agent CLIs

Agent CLIs installed in `/home/node` persist independently of the image. Rebuilding the base image does not update them.

Enter the relevant distribution and use the vendor's official update command:

```bash
./agents.sh shell /path/to/project debian
# Run the vendor-supported update command here.
```

If an installed CLI becomes corrupted, inspect and selectively remove its files from the relevant state home. Avoid deleting the entire home until credentials and configuration have been backed up.

## 20. Safe cleanup

Inspect before deleting:

```bash
podman system df
podman ps -a
podman image ls
podman volume ls
```

Remove managed containers:

```bash
./agents.sh down --all
```

Remove only the Debian image:

```bash
podman image rm localhost/containers-agents:debian-node24
```

Remove only the Fedora image:

```bash
podman image rm localhost/containers-agents:fedora44
```

Do not use these as routine commands:

```bash
podman system reset --force
podman system prune -af --volumes
```

They can remove unrelated images, caches, volumes, or persistent data.

## 21. Backing up state

Stop containers first:

```bash
./agents.sh down --all
```

Create a private backup:

```bash
tar -czf containers-agents-state-backup.tar.gz \
  -C /home/jose/Scripts/Development/ContainersAgents state
chmod 600 containers-agents-state-backup.tar.gz
```

The archive may contain access tokens. Store it as a secret.

## 22. Resetting one distribution's state

Stop all sessions:

```bash
./agents.sh down --all
```

Move the home instead of immediately deleting it:

```bash
mv state/fedora/home state/fedora/home.old
mkdir -m 700 -p state/fedora/home
```

The controller recreates shell initialization files on the next start.

After confirming the new state works, securely handle or delete the old directory according to your credential policy.

## 23. Troubleshooting

### 23.1 Permission errors in `/workspace`

Check the host account IDs:

```bash
id
```

Rebuild both images with the current account:

```bash
./agents.sh build all
```

### 23.2 A second session is refused

Check:

```bash
./agents.sh status
podman ps
```

Stop the existing project runtime:

```bash
./agents.sh down /path/to/project
```

### 23.3 `off-check` reports an unrelated container

List it:

```bash
podman ps
```

Stop it through the tool or command that created it. `down --all` removes only containers labeled as managed by this repository.

### 23.4 `podman.socket` remains active

```bash
systemctl --user disable --now podman.socket
systemctl --user stop podman.service
loginctl disable-linger "$USER"
```

Then:

```bash
./agents.sh off-check
```

### 23.5 A rootless Podman pause process remains

The normal `off-check` verifies containers, Podman API activation units, and lingering. To also stop Podman's rootless namespace pause process:

```bash
./agents.sh deep-off
```

Run no additional Podman or controller commands afterward. Use this only after `off-check` passes; the operation is not a substitute for stopping application containers.

### 23.6 Fedora or Debian package build fails

Retry after confirming network access and the base image/repository status:

```bash
./agents.sh build fedora
./agents.sh build debian
```

Do not switch to an unpinned rolling distribution as a workaround. Review and deliberately update the corresponding Containerfile when a release reaches end of life.

### 23.7 VS Code uses Docker instead of Podman

Verify the user setting:

```json
"dev.containers.dockerPath": "podman"
```

Remove a stale `DOCKER_HOST` variable from the shell and VS Code launch environment.

### 23.8 VS Code configuration points to the wrong distribution

Regenerate with a backup:

```bash
./agents.sh init-vscode /path/to/project fedora battery --force
```

### 23.9 Agent command disappears after image rebuild

User-installed commands should be under the mounted distribution home. Check:

```bash
printf '%s\n' "$PATH"
ls -la "$HOME/.local/bin" "$HOME/.npm-global/bin"
```

Reinstall using the vendor's official instructions if the command was previously installed into the ephemeral image root filesystem.

## 24. Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `CONTAINERS_AGENTS_DISTRO` | Default distribution | `debian` |
| `CONTAINERS_AGENTS_PROFILE` | Default resource profile | `auto` |
| `CONTAINERS_AGENTS_CPUS` | Override CPU quota | Profile value |
| `CONTAINERS_AGENTS_MEMORY` | Override memory limit | Profile value |
| `CONTAINERS_AGENTS_SHM` | Override shared-memory size | Profile value |
| `CONTAINERS_AGENTS_IMAGE_DEBIAN` | Override Debian image name | `localhost/containers-agents:debian-node24` |
| `CONTAINERS_AGENTS_IMAGE_FEDORA` | Override Fedora image name | `localhost/containers-agents:fedora44` |
| `CONTAINERS_AGENTS_HOME_DEBIAN` | Override Debian state home | Repository `state/debian/home` |
| `CONTAINERS_AGENTS_HOME_FEDORA` | Override Fedora state home | Repository `state/fedora/home` |

## 25. Command reference

| Command | Function |
|---|---|
| `doctor` | Inspect host/runtime configuration and image presence |
| `build TARGET` | Build `debian`, `fedora`, or `all` |
| `images` | Show local profile image metadata |
| `image-info TARGET` | Print effective versions inside one or both images |
| `shell PROJECT ...` | Start a foreground disposable shell |
| `up PROJECT ...` | Start a detached managed container |
| `exec PROJECT DISTRO` | Enter a detached container |
| `down PROJECT [DISTRO]` | Remove project containers, optionally one distribution |
| `down --all` | Remove all managed containers |
| `status` | List managed containers |
| `init-vscode PROJECT ...` | Generate Dev Container JSON |
| `vscode PROJECT ...` | Open the project in VS Code |
| `disable-background` | Disable Podman API activation and lingering |
| `off-check` | Verify no rootless container workload, Podman API activation unit, or lingering remains |
| `deep-off` | After `off-check`, stop the rootless namespace pause process as the final Podman command |

## 26. Uninstall

Stop and verify first:

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh down --all
./agents.sh disable-background
./agents.sh off-check
```

Remove the two known images if desired:

```bash
podman image rm localhost/containers-agents:debian-node24
podman image rm localhost/containers-agents:fedora44
```

Back up state if needed, then remove the repository:

```bash
rm -rf /home/jose/Scripts/Development/ContainersAgents
```

Removing Podman itself is optional and may affect other container workflows:

```bash
sudo apt remove podman uidmap
```


## 27. Source references

- OpenAI Codex CLI: <https://developers.openai.com/codex/cli/>
- Anthropic Claude Code setup: <https://docs.anthropic.com/en/docs/claude-code/setup>
- Podman system service: <https://docs.podman.io/en/latest/markdown/podman-system-service.1.html>
- Podman system migrate: <https://docs.podman.io/en/latest/markdown/podman-system-migrate.1.html>
- Podman run: <https://docs.podman.io/en/latest/markdown/podman-run.1.html>
- Dev Container JSON reference: <https://containers.dev/implementors/json_reference/>
- VS Code alternative container engines: <https://code.visualstudio.com/remote/advancedcontainers/docker-options>
