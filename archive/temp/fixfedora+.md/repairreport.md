# ContainersAgents 3.1 Repair Report

## Confirmed defects

### Fedora passwordless sudo

Fedora installed `sudo` and the NOPASSWD sudoers rule, but the `node` account was
created with a locked shadow password. Fedora's PAM account stack rejected the
account before sudoers authorization, producing:

```
sudo: PAM account management error: Authentication service cannot retrieve authentication info
sudo: a password is required
```

The Fedora image now assigns `node` a random valid password hash whose plaintext
is not logged or retained, then verifies `sudo -n true` during the image build.
The password remains unknown and interactive sudo continues to be passwordless.

### Resource-limit update on stopped containers

The controller previously called `podman update` before starting a persistent
container. With Podman 4.9 and crun, this attempted to update a runtime status
file that does not exist while stopped. Limit updates now occur after start.

## Usability improvements

- `nano`, `neovim`, and `tree` are preinstalled in Debian and Fedora.
- `agent-pkg` provides common commands across distributions:

```bash
agent-pkg update
agent-pkg install nano neovim tree
agent-pkg remove tree
agent-pkg upgrade
agent-pkg search package-name
agent-pkg clean
```

Native package managers remain available:

- Debian: `sudo apt-get install -y PACKAGE`
- Fedora: `sudo dnf install -y PACKAGE`

## Required migration

Install the updated files, then rebuild Fedora because the current Fedora
container was created from the broken image:

```bash
cd /home/jose/Scripts/Development/ContainersAgents
./agents.sh stop all
./agents.sh rebuild fedora --yes
./agents.sh image-info fedora
./agents.sh shell fedora battery
```

The Fedora `/home/node` state and `/workspace` project are host mounts and remain
preserved. The Fedora writable OS layer is intentionally recreated.

Rebuilding Debian is optional. Its current manually installed packages persist.
Rebuild Debian later only when you want the new helper and preinstalled editors
in the base image.
