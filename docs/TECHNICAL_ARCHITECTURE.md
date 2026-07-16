# Technical and architectural report

**Architecture status:** Persistent rootless YOLO  
**Primary host target:** Ubuntu 24.04 with rootless Podman  
**Also documented:** macOS via Podman Machine / Podman Desktop

## 1. Objective

Give autonomous coding agents broad administrative freedom inside two long-lived
Linux user spaces, while keeping a narrow, explicit connection to the host and
no idle container workload when the environments are not in use.

The design optimizes for:

- terminal-first agent workflows (Codex, Claude Code, and similar CLIs);
- optional VS Code attach to the same container;
- Debian as the default profile and Fedora as a second toolchain;
- passwordless `sudo` **inside** the container only;
- stop-without-remove persistence for packages installed at runtime;
- no always-on Podman API socket and no required user lingering.

## 2. Runtime topology

```text
Host kernel (Linux, or a Podman VM kernel on macOS)
└── rootless Podman
    ├── containers-agent-debian
    │   ├── persistent writable container layer
    │   ├── project bind mount  → /workspace
    │   └── Debian agent home   → /home/node  (state/debian/home)
    └── containers-agent-fedora
        ├── persistent writable container layer
        ├── same project bind mount → /workspace
        └── Fedora agent home       → /home/node  (state/fedora/home)
```

The containers share the host (or Podman VM) kernel but have separate process,
mount, user, network, hostname, and filesystem namespaces. They are not virtual
machines of the guest OS, though on macOS Podman itself runs Linux guests inside
a lightweight VM.

## 3. Components

### 3.1 `agents.sh`

Thin entry point. Resolves the repository directory and `exec`s `agentctl`.

### 3.2 `agentctl`

Bash lifecycle controller. Responsibilities:

- distribution selection (`debian` / `fedora`);
- image build and metadata (`build`, `image-info`, `images`);
- power-profile resolution and cgroup ceilings;
- fixed container create/start/exec/stop;
- project and agent-home mount construction;
- reset / rebuild / legacy migration;
- host diagnostics (`doctor`, `disable-background`, `off-check`, `deep-off`).

It is intentionally Bash so it can be audited without an extra runtime.

### 3.3 Configuration

`containers-agents.conf` is sourced after `ROOT_DIR` is known. Key defaults:

| Setting | Role |
|---|---|
| `DEFAULT_DISTRO` | No-argument distribution (`debian`) |
| `DEFAULT_PROFILE` | Power profile (`auto`) |
| `DEFAULT_PROJECT` | Shared project bind mount |
| `AUTO_STOP_AFTER_SHELL` | Stop after `shell` exits (keep writable layer) |
| `STOP_OTHER_DISTRO_ON_START` | Stop the other distro before start |
| `BATTERY_*` / `BALANCED_*` / `AC_*` | CPU and memory ceilings |
| `SHM_SIZE` / `PIDS_LIMIT` | Shared memory and PID ceilings |

Environment overrides such as `CONTAINERS_AGENTS_DISTRO` and
`CONTAINERS_AGENTS_PROJECT` are supported by `agentctl`.

### 3.4 Images

| Distro | Containerfile | Local image tag | Base |
|---|---|---|---|
| Debian | `Containerfile.debian` | `localhost/containers-agents:debian-node24-yolo` | `node:24-trixie-slim` |
| Fedora | `Containerfile.fedora` | `localhost/containers-agents:fedora44-yolo` | `fedora-minimal:44` |

Both images:

- create/adjust user `node` to the host build UID/GID;
- install development tools, sudo, Codex, and Claude Code (when enabled);
- install `node ALL=(ALL) NOPASSWD:ALL` under `/etc/sudoers.d/`;
- run as `node` with `WORKDIR /workspace` and `CMD ["sleep", "infinity"]`.

Fedora additionally sets `/etc/shadow` and `/etc/gshadow` to mode `0400`. Fedora
packages those files as mode `0000`, which full systems open via
`CAP_DAC_OVERRIDE`. Rootless container root lacks that capability, so PAM
cannot read a mode-`0000` shadow file and passwordless sudo fails before the
NOPASSWD rule is applied.

### 3.5 Fixed containers

Exactly two managed containers:

- `containers-agent-debian`
- `containers-agent-fedora`

They are labeled for controller ownership (`io.jose.containers-agents.managed`
and related labels). There is no per-project container name in the current
design.

## 4. Fixed mount boundary

Default project (configurable):

```text
<repo>/projects/container-agent-test  →  /workspace
```

Agent homes (independent per distro):

```text
<repo>/state/debian/home  →  Debian /home/node
<repo>/state/fedora/home  →  Fedora /home/node
```

Not mounted:

- the full host home directory;
- the host root filesystem;
- the Podman / Docker engine socket.

The project and agent homes are intentionally writable. File changes and
deletions on those mounts are real host changes.

## 5. Persistent-container lifecycle

A managed container has three relevant states:

1. **Absent** — no writable layer. The next `shell` or `start` creates it from
   the image.
2. **Stopped** — writable layer and mounts remain; container process CPU/RAM is
   effectively zero.
3. **Running** — `sleep infinity` (or equivalent) and any agent processes are
   active.

Default daily flow:

```text
ensure image → ensure persistent container → start → podman exec bash → stop
```

`stop` does **not** remove the container. OS packages installed with
`sudo apt` / `sudo dnf` therefore survive the next session.

| Action | Writable OS layer | `/workspace` | `/home/node` |
|---|---|---|---|
| `shell` exit (default) | kept (container stopped) | kept | kept |
| `stop` | kept | kept | kept |
| `reset --yes` | removed | kept | kept |
| `rebuild --yes` | removed after image rebuild | kept | kept |

## 6. Identity and sudo

Interactive user: `node`, UID/GID matched to the host user at image build time
so project files keep normal ownership under `--userns=keep-id`.

Sudoers policy:

```text
node ALL=(ALL) NOPASSWD:ALL
```

`sudo` becomes root **inside the container user namespace**. Under rootless
Podman, that maps into the host user's subordinate ID range, not host UID 0. It
cannot use the host's sudo policy.

No `--privileged` flag, host PID namespace, host root mount, or engine socket is
provided.

## 7. Persistence tiers

### Image layer

Baseline distribution, toolchain, Codex, Claude Code, sudo, and common
utilities. Rebuilt only when requested.

### Container writable layer

Interactive `apt` / `dnf` and other OS changes. Persists across stop/start.
Removed by `reset` or `rebuild`.

### Agent home bind mount

Authentication, settings, histories, caches, and optional user-local tools.
Survives container removal and image rebuild. Debian and Fedora homes are
separate so native modules and Python envs do not cross-contaminate.

### Project bind mount

The real project tree, visible to the host and the selected container at the
same time.

## 8. Storage and capacity

Podman does not preallocate a fixed virtual disk for these containers. Images,
writable layers, project files, and agent homes consume ordinary host (or
Podman VM) disk as data grows.

- Memory and CPU values are **ceilings**, not reservations.
- Stopped containers consume disk, not runtime CPU/RAM.
- Inspect with `podman system df`, `podman images`, `podman ps -a --size`, and
  `du -sh projects state`.

Avoid routine `podman system prune --volumes`; it can remove unrelated caches
and volumes.

## 9. Power behavior

| Profile | CPU ceiling | Memory ceiling | Typical use |
|---|---:|---:|---|
| battery | 4 CPUs | 10 GiB | laptop on battery |
| balanced | 8 CPUs | 16 GiB | moderate work |
| AC | 12 CPUs | 22 GiB | plugged in, heavy agents |

`auto` reads `/sys/class/power_supply` on Linux. Systems with no battery
devices are treated as AC-powered. On macOS, that sysfs path is normally absent
inside the controller's environment, so `auto` behaves like AC unless a profile
is set explicitly.

Shared defaults also include `SHM_SIZE=1g` and `PIDS_LIMIT=4096`.

## 10. Concurrency policy

Both distributions mount the same project. By default,
`STOP_OTHER_DISTRO_ON_START=1` stops the other distribution before starting the
selected one, so two autonomous agents do not edit the same tree concurrently.

## 11. Security architecture

### Trust boundary — allowed

- read/write the selected project;
- read/write the selected agent home;
- mutate the container writable root (`/etc`, `/usr`, `/var`, …) via sudo;
- outbound network via normal rootless networking.

### Trust boundary — denied by design

- host UID 0 / host sudo;
- unmounted host paths;
- Podman/Docker socket control plane;
- privileged devices and host namespaces.

### Risk notes

- Passwordless container sudo lets an agent install packages, break the
  writable layer, and modify mounted project/home data as root **inside** the
  namespace.
- Containers share a kernel with the host (or Podman VM); isolation is weaker
  than a full hardware VM.
- Credentials live under `state/*/home` and are gitignored; treat them as
  secrets.
- Never bake API keys into a Containerfile or image build step.

## 12. Network

Containers get normal rootless outbound networking. No inbound host ports are
published by default. Add publishing only for a specific project need.

## 13. VS Code model

VS Code is an attach client, not a second lifecycle:

1. `./agents.sh start debian` (or fedora)
2. **Dev Containers: Attach to Running Container...**
3. Open `/workspace`
4. `./agents.sh stop …` and `./agents.sh off-check` when finished

This uses the same persistent writable layer as the terminal workflow.

## 14. Controller command surface

| Command | Purpose |
|---|---|
| `shell` | Start, enter Bash, stop on exit (default) |
| `start` / `up` | Start and leave running |
| `exec` | Enter an already-running container |
| `stop` / `down` | Stop; preserve writable layer |
| `build` | Build image(s) |
| `image-info` / `images` | Version and size metadata |
| `status` | Running/stopped overview |
| `reset --yes` | Drop writable layer |
| `rebuild --yes` | Rebuild image and drop writable layer |
| `migrate-legacy --yes` | Remove pre-v3 managed containers |
| `doctor` | Host diagnostics |
| `disable-background` | Disable rootless socket/lingering (Linux) |
| `off-check` / `deep-off` | Verify inactive off-state |

## 15. Explicit non-goals

- Always-on agent containers or Podman API services
- Mounting the full host home for convenience
- Safe vs YOLO dual-image runtime (removed; YOLO-only persistent model)
- Disposable `--rm` shells as the default persistence model
- Per-project generated Dev Container stacks as the primary path
