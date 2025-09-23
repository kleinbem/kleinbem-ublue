#!/bin/bash

# This script is designed to be idempotent and can be run safely multiple times.
set -ouex pipefail

EMPTY_DIRS=(/opt /srv /home /usr/local)

check_empty() {
  local d rc=0 args=("$@"); [[ ${#args[@]} -gt 0 ]] || args=("${EMPTY_DIRS[@]}")
  for d in "${args[@]}"; do
    if [[ -d $d && -n $(find "$d" -mindepth 1 -print -quit 2>/dev/null) ]]; then
      echo "$d: not empty"
      ls -A "$d" 2>/dev/null || true
      rc=1
    fi
  done
  return $rc
}

check_empty "${EMPTY_DIRS[@]}"

## -- SYSTEM CONFIGURATION -- ##

# Enable podman socket for running rootless containers
systemctl enable podman.socket

## -- REPOSITORY SETUP -- ##

# Enable Google Chrome repository
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/google-chrome.repo

# Enable negativo17 multimedia repository and set its priority
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
echo 'priority=90' | tee -a /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# Set priority for the built-in RPM Fusion repositories
sed -i -e '$apriority=99' /etc/yum.repos.d/rpmfusion-*.repo

## -- PACKAGE INSTALLATION -- ##

# Manually create the directory for Google Chrome before installation
mkdir -p /var/opt/google/chrome-beta

# Define lists of packages to install
# This makes it easy to manage and see what's being added.
base_packages=(
  "google-chrome-beta"
)

utility_packages=(
  ""
)

# Combine all package lists into one
packages_to_install=(
  ${base_packages[@]}
  ${utility_packages[@]}
)

# Install all defined packages from the enabled repositories
dnf5 install -y ${packages_to_install[@]}

# move ot to /user/lib and symlink to /usr/bin

mv /opt/google/chrome-beta /usr/lib/google-chrome-beta && \
    ln -sf /usr/lib/google-chrome-beta/google-chrome-beta /usr/bin/google-chrome-beta


check_empty "${EMPTY_DIRS[@]}"

## -- TODO for your base image -- ##
# The following are your notes on packages to consider moving into your
# declarative build file for a truly custom base image.

# High-priority candidates:
# Podman Desktop, Cockpit Client, GNOME Builder, Arduino IDE,
# Sysd Manager, DevToolbox, ... scrcpy

# Lower-priority candidates (depends on workflow):
# Geany, DBeaver, GitKraken, LACT, Solaar

## -- CLEANUP -- ##


## -- TESTING -- ##
test -x /usr/lib/google-chrome-beta/google-chrome-beta || echo "chrome-binary missing"
test -L /usr/bin/google-chrome-beta || echo "chrome symlink missing"
