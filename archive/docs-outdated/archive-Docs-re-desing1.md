# Option B revision: persistent Debian and Fedora YOLO containers

## Decision from the latest design review

The previous four-variant safe/YOLO design has been replaced with a simpler
operating model:

- exactly two container images: Debian and Fedora;
- exactly two fixed persistent containers;
- passwordless sudo inside both containers by default;
- Debian as the no-argument default;
- one fixed project directory under the controller repository;
- no project path required on the command line;
- automatic AC/battery resource selection remains;
- leaving the shell stops the container but does not remove it;
- packages installed interactively persist until an explicit reset.

## Default command

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh shell
```

This uses:

```text
distribution: Debian
container:    containers-agent-debian
project:      /home/jose/Scripts/Development/ContainersAgents/projects/container-agent-test
container cwd:/workspace
access:       node user with passwordless container sudo
power:        auto
exit action:  stop, not remove
```

Fedora requires only one extra word:

```bash
./agents.sh shell fedora
```

## Why packages now persist

The earlier `shell` command used `podman run --rm`, so exiting destroyed the
container writable layer. The revised controller uses a named container,
starts it, enters with `podman exec`, and stops it afterward. A stopped
container retains its writable layer.

Therefore these survive the next session:

```bash
sudo apt-get install <package>
sudo dnf install <package>
```

They are lost only after:

```bash
./agents.sh reset <distro> --yes
./agents.sh rebuild <distro> --yes
```

The project and agent home survive those operations because they are bind
mounts on the host.

## Security boundary

Passwordless sudo means the `node` user can become root inside the container
without entering a password. The containers are still rootless Podman
containers. No host root filesystem, full host home, privileged mode, or
Podman socket is mounted.

The two intentional writable host connections are:

```text
projects/container-agent-test -> /workspace
state/<distro>/home           -> /home/node
```

An autonomous agent can modify or delete data in those locations. This is the
intended development boundary.

## Option B installation

Extract the complete bundle to a temporary directory:

```bash
mkdir -p /tmp/containers-agents-v3

tar -xzf ContainersAgents-Persistent-YOLO.tar.gz \
  -C /tmp/containers-agents-v3
```

Apply it to the existing installation while preserving `state` and `projects`:

```bash
/tmp/containers-agents-v3/ContainersAgents/install-update.sh --yes
```

Then initialize the revised architecture:

```bash
cd /home/jose/Scripts/Development/ContainersAgents

./agents.sh disable-background
unset DOCKER_HOST
./agents.sh migrate-legacy --yes
./agents.sh doctor
./agents.sh build all
./agents.sh image-info all
```

Start the default Debian environment:

```bash
./agents.sh shell
```

Inside it, verify:

```bash
pwd
whoami
sudo -n true
cat /etc/os-release
```

Expected essentials:

```text
/workspace
node
sudo exits successfully
Debian GNU/Linux
```

## Daily shutdown

Normally, typing `exit` stops the selected container automatically while
preserving it. Verify the no-workload state with:

```bash
./agents.sh off-check
```

The check permits stopped persistent containers but rejects running containers
and Podman API activation.
