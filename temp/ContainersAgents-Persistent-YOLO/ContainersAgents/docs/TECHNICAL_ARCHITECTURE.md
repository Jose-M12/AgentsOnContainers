# Technical architecture report

## 1. Objective

Provide autonomous coding agents with broad administrative freedom inside two
long-lived Linux user spaces while retaining a narrow, explicit connection to
the Ubuntu host and no idle container workload when the environments are not
being used.

## 2. Runtime topology

```text
Ubuntu host kernel
└── rootless Podman
    ├── containers-agent-debian
    │   ├── persistent writable container layer
    │   ├── project bind mount -> /workspace
    │   └── Debian agent home -> /home/node
    └── containers-agent-fedora
        ├── persistent writable container layer
        ├── same project bind mount -> /workspace
        └── Fedora agent home -> /home/node
```

The containers share the host kernel but have separate process, mount, user,
network, hostname, and filesystem namespaces. They are not virtual machines.

## 3. Fixed mount boundary

The configured default project is:

```text
/home/jose/Scripts/Development/ContainersAgents/projects/container-agent-test
```

It appears inside either container as:

```text
/workspace
```

The complete `/home/jose` tree is not mounted. The Podman socket is not mounted.

The agent homes are independent:

```text
state/debian/home -> Debian /home/node
state/fedora/home -> Fedora /home/node
```

This prevents distribution-specific native modules and configuration from
cross-contaminating each other.

## 4. Persistent-container lifecycle

A container has three relevant states:

1. **Absent:** no writable layer exists. The next `shell` or `start` creates it.
2. **Stopped:** writable layer and mounted state remain; CPU and RAM use from
   container processes is zero.
3. **Running:** its `sleep infinity` anchor process and any agent processes are
   active.

`./agents.sh shell` performs:

```text
ensure image -> ensure persistent container -> start -> podman exec bash -> stop
```

The final stop does not remove the container. Therefore OS packages installed
with sudo survive the next session.

## 5. Identity and sudo

The interactive user is `node`, with UID/GID matched to the host user for
normal project-file ownership. The image installs this sudoers policy:

```text
node ALL=(ALL) NOPASSWD:ALL
```

`sudo` changes identity to root inside the container user namespace. Under
rootless Podman, container root is mapped into the host user's subordinate ID
range, not to host UID 0. It cannot invoke Ubuntu's host sudo policy.

No `--privileged`, host PID namespace, host root mount, or container-engine
socket is provided.

## 6. Persistence tiers

### Image layer

Contains the baseline distribution, development toolchain, Codex CLI, Claude
Code, sudo, and common utilities. Rebuilt deliberately.

### Container writable layer

Contains interactive `apt`, `dnf`, and other operating-system modifications.
Persists across stop/start. Removed by `reset` or `rebuild`.

### Agent home bind mount

Contains authentication, agent settings, histories, caches, and optional
user-local tools. Persists across container removal and image rebuild.

### Project bind mount

Contains the actual project and is visible to Ubuntu and the selected container
at the same time. Changes and deletions are real host changes.

## 7. Power behavior

Power profiles are cgroup ceilings, not reservations:

| Profile | CPU ceiling | Memory ceiling |
|---|---:|---:|
| battery | 4 CPUs | 10 GiB |
| balanced | 8 CPUs | 16 GiB |
| AC | 12 CPUs | 22 GiB |

`auto` detects mains power from `/sys/class/power_supply`. Existing persistent
containers receive updated CPU and memory ceilings before being started.

Stopped containers consume disk only. Images and writable layers do not reserve
RAM or CPU.

## 8. Concurrency policy

Both distributions mount the same project. By default, starting one stops the
other first. This prevents two autonomous agents from concurrently mutating the
same working tree. The behavior is controlled by
`STOP_OTHER_DISTRO_ON_START` in `containers-agents.conf`.

## 9. Reset boundary

`stop` preserves the container. `reset --yes` removes the writable layer but
preserves the project and agent home. `rebuild --yes` builds a new image and
then removes the old persistent container so the next session starts from the
new baseline.
