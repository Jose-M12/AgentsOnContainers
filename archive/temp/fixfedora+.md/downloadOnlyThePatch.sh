diff -ruN ca-current/ContainersAgents/Containerfile.debian ca-v31/Containerfile.debian
--- ca-current/ContainersAgents/Containerfile.debian	2026-07-12 23:02:20.000000000 +0000
+++ ca-v31/Containerfile.debian	2026-07-12 23:45:53.791445395 +0000
@@ -13,7 +13,7 @@
     apt-get install -y --no-install-recommends \
       bash build-essential ca-certificates curl file git git-lfs gpg jq less \
       openssh-client pkg-config procps python3 python3-pip python3-venv \
-      ripgrep rsync sudo unzip xz-utils zip; \
+      ripgrep rsync sudo tree nano neovim unzip xz-utils zip; \
     rm -rf /var/lib/apt/lists/*
 
 # Install executable agent tools in image-managed system paths. Authentication,
@@ -43,7 +43,11 @@
     mkdir -p /workspace /home/node/.local/bin /home/node/.npm-global; \
     chown -R "$USER_ID:$GROUP_ID" /workspace /home/node; \
     printf 'node ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-containers-agents-node; \
-    chmod 0440 /etc/sudoers.d/90-containers-agents-node
+    chmod 0440 /etc/sudoers.d/90-containers-agents-node; \
+    su -s /bin/bash node -c 'sudo -n true'
+
+COPY extras/agent-pkg /usr/local/bin/agent-pkg
+RUN chmod 0755 /usr/local/bin/agent-pkg
 
 COPY extras/install-debian.sh /tmp/containers-agents-install-extra.sh
 RUN chmod 0755 /tmp/containers-agents-install-extra.sh \
diff -ruN ca-current/ContainersAgents/Containerfile.fedora ca-v31/Containerfile.fedora
--- ca-current/ContainersAgents/Containerfile.fedora	2026-07-12 23:02:20.000000000 +0000
+++ ca-v31/Containerfile.fedora	2026-07-12 23:45:53.791700545 +0000
@@ -11,7 +11,7 @@
     dnf -y --setopt=install_weak_deps=False install \
       bash ca-certificates curl file findutils gcc gcc-c++ git git-lfs gnupg2 \
       jq less make nodejs openssh-clients pkgconf-pkg-config procps-ng \
-      python3 python3-pip ripgrep rsync shadow-utils sudo unzip which xz zip; \
+      python3 python3-pip ripgrep rsync shadow-utils sudo tree nano neovim unzip which xz zip; \
     (command -v npm >/dev/null 2>&1 \
       || dnf -y --setopt=install_weak_deps=False install nodejs-npm \
       || dnf -y --setopt=install_weak_deps=False install npm); \
@@ -51,6 +51,18 @@
     printf 'node ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-containers-agents-node; \
     chmod 0440 /etc/sudoers.d/90-containers-agents-node
 
+# Fedora PAM rejects an account whose shadow password is locked, even when the
+# matching sudoers rule is NOPASSWD. Give node a valid random password hash; the
+# plaintext is neither logged nor retained, and sudo still never asks for it.
+RUN set -eu; \
+    random_password="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"; \
+    printf 'node:%s\n' "$random_password" | chpasswd; \
+    unset random_password; \
+    su -s /bin/bash node -c 'sudo -n true'
+
+COPY extras/agent-pkg /usr/local/bin/agent-pkg
+RUN chmod 0755 /usr/local/bin/agent-pkg
+
 COPY extras/install-fedora.sh /tmp/containers-agents-install-extra.sh
 RUN chmod 0755 /tmp/containers-agents-install-extra.sh \
     && /tmp/containers-agents-install-extra.sh \
diff -ruN ca-current/ContainersAgents/ContainersAgents-3.1-Repair-Report.md ca-v31/ContainersAgents-3.1-Repair-Report.md
--- ca-current/ContainersAgents/ContainersAgents-3.1-Repair-Report.md	1970-01-01 00:00:00.000000000 +0000
+++ ca-v31/ContainersAgents-3.1-Repair-Report.md	2026-07-12 23:46:07.743799460 +0000
@@ -0,0 +1,63 @@
+# ContainersAgents 3.1 Repair Report
+
+## Confirmed defects
+
+### Fedora passwordless sudo
+
+Fedora installed `sudo` and the NOPASSWD sudoers rule, but the `node` account was
+created with a locked shadow password. Fedora's PAM account stack rejected the
+account before sudoers authorization, producing:
+
+```
+sudo: PAM account management error: Authentication service cannot retrieve authentication info
+sudo: a password is required
+```
+
+The Fedora image now assigns `node` a random valid password hash whose plaintext
+is not logged or retained, then verifies `sudo -n true` during the image build.
+The password remains unknown and interactive sudo continues to be passwordless.
+
+### Resource-limit update on stopped containers
+
+The controller previously called `podman update` before starting a persistent
+container. With Podman 4.9 and crun, this attempted to update a runtime status
+file that does not exist while stopped. Limit updates now occur after start.
+
+## Usability improvements
+
+- `nano`, `neovim`, and `tree` are preinstalled in Debian and Fedora.
+- `agent-pkg` provides common commands across distributions:
+
+```bash
+agent-pkg update
+agent-pkg install nano neovim tree
+agent-pkg remove tree
+agent-pkg upgrade
+agent-pkg search package-name
+agent-pkg clean
+```
+
+Native package managers remain available:
+
+- Debian: `sudo apt-get install -y PACKAGE`
+- Fedora: `sudo dnf install -y PACKAGE`
+
+## Required migration
+
+Install the updated files, then rebuild Fedora because the current Fedora
+container was created from the broken image:
+
+```bash
+cd /home/jose/Scripts/Development/ContainersAgents
+./agents.sh stop all
+./agents.sh rebuild fedora --yes
+./agents.sh image-info fedora
+./agents.sh shell fedora battery
+```
+
+The Fedora `/home/node` state and `/workspace` project are host mounts and remain
+preserved. The Fedora writable OS layer is intentionally recreated.
+
+Rebuilding Debian is optional. Its current manually installed packages persist.
+Rebuild Debian later only when you want the new helper and preinstalled editors
+in the base image.
diff -ruN ca-current/ContainersAgents/README.md ca-v31/README.md
--- ca-current/ContainersAgents/README.md	2026-07-12 23:05:33.000000000 +0000
+++ ca-v31/README.md	2026-07-12 23:45:32.502845645 +0000
@@ -138,3 +138,17 @@
 - `docs/SETUP_AND_USAGE.md`
 - `docs/PERSISTENCE_STORAGE_AND_SECURITY.md`
 - `docs/MIGRATION_FROM_SAFE_YOLO.md`
+
+
+## Package management
+
+Use the same helper in either distribution:
+
+```bash
+agent-pkg update
+agent-pkg install nano neovim tree
+```
+
+The native commands remain available: `apt-get` on Debian and `dnf` on Fedora.
+Resource-limit updates are applied only after a persistent container is running,
+which avoids the stopped-container `crun update` failure seen with Podman 4.9.
diff -ruN ca-current/ContainersAgents/agentctl ca-v31/agentctl
--- ca-current/ContainersAgents/agentctl	2026-07-12 23:06:59.000000000 +0000
+++ ca-v31/agentctl	2026-07-12 23:45:32.502573765 +0000
@@ -253,6 +253,7 @@
 }
 
 apply_limits() {
+  container_running "$CONTAINER_NAME" || return 0
   if ! podman update \
       --cpus "$LIMIT_CPUS" \
       --memory "$LIMIT_MEMORY" \
@@ -301,7 +302,6 @@
   ensure_state_home
   if container_exists "$CONTAINER_NAME"; then
     validate_existing_container "$PROJECT_PATH"
-    apply_limits
   else
     create_container "$PROJECT_PATH"
   fi
@@ -325,6 +325,9 @@
     START_WAS_RUNNING=1
   else
     podman start "$CONTAINER_NAME" >/dev/null
+  fi
+  apply_limits
+  if [[ "$START_WAS_RUNNING" == 0 ]]; then
     log "Started $CONTAINER_NAME ($ACTIVE_PROFILE profile ceiling)."
   fi
 }
@@ -364,6 +367,11 @@
   trap 'cleanup_active_shell; exit 143' TERM
 
   log "Opening $ACTIVE_DISTRO shell in $PROJECT_PATH. Passwordless container sudo is enabled."
+  if [[ "$ACTIVE_DISTRO" == debian ]]; then
+    log "Packages: agent-pkg install <name>  (native: sudo apt-get install -y <name>)"
+  else
+    log "Packages: agent-pkg install <name>  (native: sudo dnf install -y <name>)"
+  fi
   if [[ "$auto_stop" == 1 && "$was_running" == 0 ]]; then
     log "Exit the shell normally; the container will stop but will not be removed."
   else
@@ -387,11 +395,11 @@
   ACTIVE_DISTRO_SAVED="$ACTIVE_DISTRO"
   stop_other_if_configured
   select_distro "$ACTIVE_DISTRO_SAVED"
-  if container_running "$CONTAINER_NAME"; then
-    log "$CONTAINER_NAME is already running."
+  start_selected
+  if [[ "$START_WAS_RUNNING" == 1 ]]; then
+    log "$CONTAINER_NAME is already running; the $ACTIVE_PROFILE limits were requested."
   else
-    podman start "$CONTAINER_NAME" >/dev/null
-    log "Started $CONTAINER_NAME. It remains running until './agents.sh stop $ACTIVE_DISTRO'."
+    log "$CONTAINER_NAME remains running until './agents.sh stop $ACTIVE_DISTRO'."
   fi
 }
 
@@ -439,7 +447,7 @@
   select_distro "$distro"
   podman image exists "$IMAGE" || die "$IMAGE is not built. Run './agents.sh build $distro'."
   log "Image information: $distro ($IMAGE)"
-  podman run --rm --entrypoint /bin/bash "$IMAGE" -lc '
+  podman run --rm --userns=keep-id --entrypoint /bin/bash "$IMAGE" -lc '
     printf "OS: "; . /etc/os-release; printf "%s %s\n" "$NAME" "$VERSION_ID"
     printf "Node: "; node --version 2>/dev/null || echo not-installed
     printf "npm: "; npm --version 2>/dev/null || echo not-installed
diff -ruN ca-current/ContainersAgents/docs/V3_1_FIXES.md ca-v31/docs/V3_1_FIXES.md
--- ca-current/ContainersAgents/docs/V3_1_FIXES.md	1970-01-01 00:00:00.000000000 +0000
+++ ca-v31/docs/V3_1_FIXES.md	2026-07-12 23:45:32.503042732 +0000
@@ -0,0 +1,23 @@
+# ContainersAgents 3.1 corrective release
+
+This release fixes four issues observed during live use:
+
+1. Fedora `sudo` PAM failure: the `node` account now receives a random, unknown
+   valid password hash so Fedora PAM considers the account active. The sudoers
+   rule remains `NOPASSWD`, and the build verifies `sudo -n true` as `node`.
+2. Dynamic resource limits are applied only after the persistent container is
+   running, avoiding `crun ... status: No such file or directory` on stopped
+   containers with Podman 4.9.
+3. `nano`, `neovim`, and `tree` are included in both images.
+4. `agent-pkg` provides one package-management command for Debian and Fedora.
+
+After installing the update, rebuild/reset Fedora because its existing writable
+container was created from the old image:
+
+```bash
+./agents.sh rebuild fedora --yes
+./agents.sh image-info fedora
+./agents.sh shell fedora battery
+```
+
+The Fedora native package manager is DNF, not APT.
diff -ruN ca-current/ContainersAgents/extras/agent-pkg ca-v31/extras/agent-pkg
--- ca-current/ContainersAgents/extras/agent-pkg	1970-01-01 00:00:00.000000000 +0000
+++ ca-v31/extras/agent-pkg	2026-07-12 23:45:32.497786442 +0000
@@ -0,0 +1,48 @@
+#!/usr/bin/env bash
+set -Eeuo pipefail
+
+usage() {
+  cat <<'EOF'
+Usage:
+  agent-pkg update
+  agent-pkg install <package>...
+  agent-pkg remove <package>...
+  agent-pkg upgrade
+  agent-pkg search <term>...
+  agent-pkg clean
+
+This wrapper selects apt on Debian and dnf on Fedora.
+EOF
+}
+
+[[ $# -ge 1 ]] || { usage >&2; exit 2; }
+action="$1"; shift
+
+as_root() {
+  if [[ $(id -u) -eq 0 ]]; then "$@"; else sudo -n "$@"; fi
+}
+
+if command -v apt-get >/dev/null 2>&1; then
+  case "$action" in
+    update)  as_root apt-get update ;;
+    install) [[ $# -gt 0 ]] || { usage >&2; exit 2; }; as_root apt-get install -y "$@" ;;
+    remove)  [[ $# -gt 0 ]] || { usage >&2; exit 2; }; as_root apt-get remove -y "$@" ;;
+    upgrade) as_root apt-get update; as_root apt-get upgrade -y ;;
+    search)  [[ $# -gt 0 ]] || { usage >&2; exit 2; }; apt-cache search "$@" ;;
+    clean)   as_root apt-get clean ;;
+    *) usage >&2; exit 2 ;;
+  esac
+elif command -v dnf >/dev/null 2>&1; then
+  case "$action" in
+    update)  as_root dnf -y makecache --refresh ;;
+    install) [[ $# -gt 0 ]] || { usage >&2; exit 2; }; as_root dnf -y install "$@" ;;
+    remove)  [[ $# -gt 0 ]] || { usage >&2; exit 2; }; as_root dnf -y remove "$@" ;;
+    upgrade) as_root dnf -y upgrade --refresh ;;
+    search)  [[ $# -gt 0 ]] || { usage >&2; exit 2; }; dnf search "$@" ;;
+    clean)   as_root dnf clean all ;;
+    *) usage >&2; exit 2 ;;
+  esac
+else
+  echo 'agent-pkg: neither apt-get nor dnf is available' >&2
+  exit 1
+fi
diff -ruN ca-current/ContainersAgents/install-update.sh ca-v31/install-update.sh
--- ca-current/ContainersAgents/install-update.sh	2026-07-12 23:07:33.000000000 +0000
+++ ca-v31/install-update.sh	2026-07-12 23:46:48.686026281 +0000
@@ -60,7 +60,8 @@
   "$TARGET_DIR/agents.sh" \
   "$TARGET_DIR/install-update.sh" \
   "$TARGET_DIR/extras/install-debian.sh" \
-  "$TARGET_DIR/extras/install-fedora.sh"
+  "$TARGET_DIR/extras/install-fedora.sh" \
+  "$TARGET_DIR/extras/agent-pkg"
 
 echo "Update installed at $TARGET_DIR"
-echo "Next: cd '$TARGET_DIR' && ./agents.sh doctor && ./agents.sh build all"
+echo "Next: cd '$TARGET_DIR' && ./agents.sh doctor && ./agents.sh rebuild fedora --yes"
