# Migration from the safe/YOLO multi-image design

## Removed concepts

The new architecture removes:

- safe images;
- safe versus YOLO runtime arguments;
- disposable `shell --rm` behavior;
- per-project container names;
- a required project-path argument;
- generated VS Code Dev Container configurations.

## New concepts

It introduces:

- exactly two fixed persistent containers;
- passwordless container sudo as the only access model;
- Debian as the no-argument default;
- one configured project mount;
- automatic stop without container removal;
- explicit `reset` and `rebuild` reset buttons;
- VS Code attachment to the same running container.

## State migration

The new containers use the existing safe home paths:

```text
state/debian/home
state/fedora/home
```

Old `yolo-home` directories are not used. Review and copy desired files from an
old YOLO home manually rather than merging credentials and executables blindly.

Example, after inspection:

```bash
rsync -a --dry-run state/debian/yolo-home/ state/debian/home/
```

Do not perform the real merge until the dry-run output is understood.

## Container migration

Old managed containers use project-specific names and are incompatible with the
fixed-name architecture. Remove them explicitly:

```bash
./agents.sh migrate-legacy --yes
```

This does not delete project directories or state homes. It does remove old
container writable layers and any packages installed only inside them.

## First use after migration

```bash
./agents.sh build all
./agents.sh shell
```

The controller creates `containers-agent-debian`. On exit, it stops and remains
available for the next session.
