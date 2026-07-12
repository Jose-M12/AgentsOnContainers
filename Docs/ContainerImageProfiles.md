# Container Image Profiles

**Report date:** 2026-07-12  
**Policy:** Debian default; Fedora optional secondary profile

## Decision

This repository supports two CLI-only images:

| Profile | Base | Role | Default |
|---|---|---|---|
| Debian | `node:24-trixie-slim` | Stable, high-compatibility agent environment | Yes |
| Fedora | `registry.fedoraproject.org/fedora-minimal:44` | Current Fedora/RPM toolchain and compatibility testing | No |

Neither image contains a desktop environment, display server, browser, or graphical application stack.

## Why Debian is the default

The Debian profile is based on the official Node.js 24 LTS image for Debian 13 Trixie. This provides a predictable Node/npm installation without adding an external Node repository during the build.

Debian is the primary profile because:

- Agent CLIs are frequently distributed through npm or Python packaging.
- Debian/glibc compatibility is broad.
- Debian Stable changes conservatively.
- The official Node image exposes an explicit `24-trixie-slim` tag.
- Debian 13 is the current stable Debian release as of July 2026.
- The `slim` base omits many general-purpose packages, and the Containerfile adds only the CLI and build tools required for development agents.

The Debian profile installs:

- Node.js 24 LTS and npm from the official Node base image.
- Python 3, pip, and `venv`.
- Git, SSH client, curl, jq, ripgrep, process inspection tools, and a basic C/C++ build toolchain.

Use Debian for day-to-day work unless the repository specifically needs Fedora or RPM behavior.

## Why Fedora is included

The Fedora profile uses Fedora Minimal 44 and installs its tools through DNF.

Fedora is useful for:

- Testing software against a current Fedora userland.
- RPM/DNF packaging or Fedora-specific scripts.
- Newer compiler, Python, and system-library behavior.
- Detecting assumptions that only hold on Debian-family systems.

Fedora moves faster and has a shorter lifecycle than Debian Stable. The Fedora Containerfile therefore pins the major Fedora release (`44`) instead of using `latest`. Move to a newer Fedora release deliberately after testing.

The exact Node.js and Python point versions are controlled by the Fedora 44 repositories at build time. Verify the built environment with:

```bash
./agents.sh image-info fedora
```

## Why both can remain installed

Container images are passive filesystem layers. When no container is running:

- They use no CPU.
- They reserve no RAM.
- They create no background workload.
- Their only ongoing cost is disk space.

Use this command to inspect actual local image sizes after building:

```bash
./agents.sh images
```

Runtime battery use depends on the active container processes and their CPU activity, not on how many stopped images are stored.

## Separate persistent homes

The profiles intentionally do not share a home directory:

```text
state/debian/home
state/fedora/home
```

This prevents the following cross-distribution problems:

- Python virtual environments embedding distribution-specific interpreter paths.
- Native npm modules compiled against different system libraries.
- Cached binaries linked to different glibc or library versions.
- Package-manager and tool caches overwriting one another.

Credentials may need to be authenticated once in each profile. This is safer than silently sharing executable state between distributions.

## Selection rules

Choose **Debian** when:

- Starting a new agent session.
- Running Claude, Codex, Aider, or another Node/Python CLI.
- Maximum package compatibility is more important than newest system packages.
- You need the least maintenance.

Choose **Fedora** when:

- The project targets Fedora or RPM systems.
- You need a newer compiler or system library.
- You want a second environment to test portability.
- A tool's Fedora installation instructions are materially better than its Debian instructions.

Do not run Debian and Fedora containers against the same project simultaneously. The controller checks the project label and refuses a second managed runtime while one is active.

## Why Alpine is not the default

Alpine can produce smaller images, but it uses musl libc instead of glibc. The official Node image documentation warns that software may encounter compatibility issues when it assumes glibc behavior. Autonomous coding agents frequently install native Node modules, Python wheels, browser tooling, or prebuilt binaries, so saving some image space is not worth the additional compatibility risk here.

## Updating the images

Image construction is manual. Nothing updates in the background.

Rebuild one profile:

```bash
./agents.sh build debian
./agents.sh build fedora
```

Rebuild both:

```bash
./agents.sh build all
```

The controller uses `--pull=always` during a requested build so the selected base tag and repository security updates are refreshed at that moment.

After rebuilding, verify versions:

```bash
./agents.sh image-info all
```

## Source references

- Debian releases: <https://www.debian.org/releases/>
- Official Node container image and supported tags: <https://hub.docker.com/_/node>
- Fedora Linux 44 release announcement: <https://fedoramagazine.org/announcing-fedora-linux-44/>
