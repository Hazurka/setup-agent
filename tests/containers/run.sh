#!/usr/bin/env bash
# Real installs of terminal-setup in Linux containers (podman or docker).
#
# For each distro: start a fresh container, add a non-root user with
# passwordless sudo (the only bootstrap), run `--apply -y` as that user, then
# a fresh `--check`, and print what is still missing.
#
# Usage: tests/containers/run.sh [distro...]
#   distros: fedora opensuse opensuse-amd64 debian12 debian13 ubuntu2404 ubuntu2504 arch
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE="${CONTAINER_ENGINE:-}"
if [ -z "$ENGINE" ]; then
  for c in podman /opt/podman/bin/podman docker; do
    if command -v "$c" >/dev/null 2>&1; then ENGINE="$c"; break; fi
  done
fi
[ -n "$ENGINE" ] || { echo "podman or docker is required" >&2; exit 2; }

image_for() {
  case "$1" in
    fedora)     echo "registry.fedoraproject.org/fedora:43" ;;
    opensuse|opensuse-amd64) echo "registry.opensuse.org/opensuse/tumbleweed:latest" ;;
    debian12)   echo "docker.io/library/debian:12" ;;
    debian13)   echo "docker.io/library/debian:13" ;;
    ubuntu2404) echo "docker.io/library/ubuntu:24.04" ;;
    ubuntu2504) echo "docker.io/library/ubuntu:25.04" ;;
    arch)       echo "docker.io/library/archlinux:latest" ;;
    *) return 1 ;;
  esac
}

# Only what a real desktop install already has: sudo and a user account.
bootstrap_for() {
  case "$1" in
    fedora)   echo "dnf install -y -q sudo shadow-utils" ;;
    opensuse*) echo "zypper -n -q install sudo shadow" ;;
    debian*|ubuntu*) echo "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo" ;;
    # pacman's download sandbox needs seccomp, unavailable under amd64 emulation.
    arch)     echo "sed -i '/^\\[options\\]/a DisableSandbox' /etc/pacman.conf && pacman -Syu --noconfirm --needed sudo" ;;
  esac
}

# Always explicit: images sharing a tag (opensuse / opensuse-amd64) would
# otherwise reuse whichever architecture was pulled last.
NATIVE_ARCH="$("$ENGINE" info --format '{{.Host.Arch}}' 2>/dev/null || echo amd64)"
platform_for() {
  # The official Arch image is amd64-only.
  # opensuse-amd64 exercises the x86_64-only zsh-users OBS repos.
  case "$1" in
    arch|*-amd64) echo "--platform=linux/amd64" ;;
    *) echo "--platform=linux/$NATIVE_ARCH" ;;
  esac
}

DISTROS=("$@")
[ ${#DISTROS[@]} -gt 0 ] || DISTROS=(fedora opensuse opensuse-amd64 debian12 debian13 ubuntu2404 ubuntu2504 arch)
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
echo "Engine: $ENGINE   Logs: $LOG_DIR"

SUMMARY=()
for d in "${DISTROS[@]}"; do
  image="$(image_for "$d")" || { echo "unknown distro: $d" >&2; exit 2; }
  log="$LOG_DIR/$d.log"
  echo ""
  echo "== $d ($image)"
  # shellcheck disable=SC2046 # platform flag is intentionally word-split
  "$ENGINE" run --rm $(platform_for "$d") -e DEBIAN_FRONTEND=noninteractive \
    -v "$REPO_DIR:/repo:ro" "$image" bash -c "
      set -e
      $(bootstrap_for "$d") >/dev/null
      useradd -m -s /bin/bash tester
      echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
      chmod 440 /etc/sudoers.d/tester
      cd /home/tester
      set +e
      sudo -u tester -H bash /repo/skills/terminal-setup/scripts/verify-or-install.sh --apply -y
      echo \"APPLY_EXIT=\$?\"
      sudo -u tester -H bash /repo/skills/terminal-setup/scripts/verify-or-install.sh --check
      echo \"CHECK_EXIT=\$?\"
    " >"$log" 2>&1
  apply_rc="$(sed -n 's/^APPLY_EXIT=//p' "$log")"
  check_rc="$(sed -n 's/^CHECK_EXIT=//p' "$log")"
  missing=""
  # Only the final --check matters; earlier "Missing:" lines are pre-apply.
  if [ "${check_rc:-1}" != 0 ]; then
    missing="$(grep '^\[!\] Missing:' "$log" | tail -1 | sed 's/^\[!\] Missing: //')"
  fi
  grep -E '^\[!\] (Step failed|Failed step)|^\[\*\] Manual step' "$log" | sort -u
  echo "   apply exit: ${apply_rc:-?}   check exit: ${check_rc:-?}"
  [ -n "$missing" ] && echo "   still missing: $missing"
  SUMMARY+=("$(printf '%-11s apply=%-2s check=%-2s %s' "$d" "${apply_rc:-?}" "${check_rc:-?}" "$missing")")
done

echo ""
echo "== Summary"
printf '  %s\n' "${SUMMARY[@]}"
