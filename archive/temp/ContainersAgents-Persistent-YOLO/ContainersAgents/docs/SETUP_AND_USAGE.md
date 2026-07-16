# Full setup and usage report

## 1. Update an existing installation with Option B

Extract the downloaded archive into a temporary directory:

```bash
mkdir -p /tmp/containers-agents-v3
tar -xzf ContainersAgents-Persistent-YOLO.tar.gz \
  -C /tmp/containers-agents-v3
```

Run the included updater. It preserves the existing `state` and `projects`
directories:

```bash
/tmp/containers-agents-v3/ContainersAgents/install-update.sh --yes
```

Then:

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh disable-background
unset DOCKER_HOST
./agents.sh migrate-legacy --yes
./agents.sh doctor
./agents.sh build all
./agents.sh image-info all
```

The first new `shell` creates the corresponding fixed persistent container.

## 2. Default project

The controller creates and uses:

```text
/home/jose/Scripts/Development/ContainersAgents/projects/container-agent-test
```

Confirm it with:

```bash
./agents.sh project-path
```

No project argument is required during normal use.

## 3. Debian daily workflow

```bash
./agents.sh shell
```

Inside:

```bash
pwd
whoami
cat /etc/os-release
sudo -n true
codex --version
claude --version
```

Expected key values:

```text
/workspace
node
Debian GNU/Linux
```

Install a package and verify persistence:

```bash
sudo apt-get update
sudo apt-get install -y tree
exit

./agents.sh shell
tree --version
```

The second session should still have `tree` because exiting stopped rather than
removed the container.

## 4. Fedora workflow

```bash
./agents.sh shell fedora
```

Inside:

```bash
sudo dnf install -y tree
exit
```

Re-enter:

```bash
./agents.sh shell fedora
tree --version
```

## 5. Power profiles

```bash
./agents.sh shell battery
./agents.sh shell balanced
./agents.sh shell ac
./agents.sh shell fedora battery
```

With no profile, `auto` selects AC or battery.

## 6. Keep-running workflow

For multiple terminal attachments or VS Code:

```bash
./agents.sh start debian
./agents.sh exec debian
```

Or:

```bash
./agents.sh shell --keep-running
```

Stop later:

```bash
./agents.sh stop debian
```

## 7. Agent authentication

Run inside each distribution:

```bash
codex
claude
```

Credentials and settings are stored under the mounted `/home/node` and survive
container reset. Debian and Fedora use separate homes, so authenticate each one
that you intend to use.

Never place account tokens in a Containerfile or image-build script.

## 8. Update packages and agents

Interactive changes persist in the container:

```bash
# Debian
sudo apt-get update
sudo apt-get upgrade
sudo npm install -g @openai/codex@latest
sudo apt-get install --only-upgrade claude-code

# Fedora
sudo dnf upgrade
sudo npm install -g @openai/codex@latest
sudo dnf upgrade claude-code
```

For a reproducible baseline, update the Containerfile and run:

```bash
./agents.sh rebuild debian --yes
```

This removes interactive OS changes but preserves `/workspace` and `/home/node`.

## 9. Status and shutdown

```bash
./agents.sh status
./agents.sh stop all
./agents.sh off-check
```

`off-check` allows stopped persistent containers but fails if any Podman
container is running, either API socket is active/enabled, or user lingering is
enabled.

## 10. VS Code

```bash
./agents.sh start debian
```

In VS Code:

1. Run **Dev Containers: Attach to Running Container...**
2. Select `containers-agent-debian`
3. Open `/workspace`

When finished:

```bash
./agents.sh stop debian
./agents.sh off-check
```

This attaches to the same persistent container used by the terminal instead of
creating another container with a different writable layer.

## 11. Recovery

If an agent breaks Debian's operating-system layer:

```bash
./agents.sh reset debian --yes
./agents.sh shell
```

If the image itself should be refreshed:

```bash
./agents.sh rebuild debian --yes
./agents.sh shell
```
