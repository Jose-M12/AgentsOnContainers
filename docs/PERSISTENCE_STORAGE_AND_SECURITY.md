# Persistence, storage, and security report

## Storage allocation

Podman does not preallocate a fixed virtual disk for these containers. Images,
container writable layers, project files, and agent homes consume ordinary SSD
space as data is added.

- Stopped containers consume disk but no container-process CPU or RAM.
- Memory values are ceilings, not reserved allocations.
- The project and agent homes are ordinary host directories.
- Packages installed with apt or dnf increase the selected container writable
  layer.

Inspect usage:

```bash
podman system df
podman images
podman ps -a --size

du -sh projects state
```

Do not run broad `podman system prune --volumes` as routine maintenance. It can
remove caches and volumes unrelated to this controller.

## Shared-project functionality

The host path and `/workspace` refer to the same underlying files. Either side
can create, edit, rename, or delete them. File watchers, Git operations, builds,
and tests work directly against the real project.

This is not a container escape; it is the intended bind-mount permission.
Commit or back up important work before giving an autonomous agent broad
approval.

## Passwordless sudo risk boundary

Passwordless sudo increases authority inside the container. An agent can:

- install and remove operating-system packages;
- modify `/etc`, `/usr`, and `/var`;
- run background processes while the container is running;
- break the container's writable filesystem;
- use root privileges to modify the mounted project and agent home.

It cannot, through this design alone:

- become host UID 0;
- use Ubuntu's sudo configuration;
- access unmounted host directories;
- control Podman through a mounted engine socket;
- obtain `--privileged` devices or host namespaces.

Containers share the host kernel, so they are a weaker isolation boundary than
a hardware virtual machine. Rootless operation and narrow mounts materially
reduce risk but do not turn untrusted code into risk-free code.

## Network

The containers receive normal rootless outbound networking. Agents can download
packages and communicate with their providers. No inbound host service is
published by default. Add port publishing only for a specific project need.

## Secrets

Agent credentials persist in:

```text
state/debian/home
state/fedora/home
```

Protect those directories as secrets. They are excluded by the included
`.gitignore`. Do not copy them into project repositories or archives intended
for sharing.
