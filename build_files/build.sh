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

# Enable repositories for Google Chrome and Visual Studio Code
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/google-chrome.repo
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/google-chrome.repo
sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/vscode.repo

# Enable negativo17 multimedia repository and set its priority
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
echo 'priority=90' | tee -a /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# Set priority for the built-in RPM Fusion repositories
sed -i -e '$apriority=99' /etc/yum.repos.d/rpmfusion-*.repo

sudo tee /etc/yum.repos.d/vscode-insiders.repo > /dev/null <<'EOF'
[code-insiders]
name=Visual Studio Code Insiders
baseurl=https://packages.microsoft.com/yumrepos/vscode-insiders
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

## -- PACKAGE INSTALLATION -- ##

# Manually create the directory for Google Chrome before installation
mkdir -p /var/opt/google/chrome-beta

# Define lists of packages to install
# This makes it easy to manage and see what's being added.
base_packages=(
  "dnf5-plugins",
  "google-chrome-beta",
  "podman-desktop",
  "code!",
  "code-insiders"
)

utility_packages=(
  ""
)

# Combine all package lists into one
packages_to_install=(
  ${base_packages[@]}
  ${utility_packages[@]}
)

dnf5 config-manager addrepo \
  "https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:podman-desktop/Fedora_$(rpm -E %fedora)/devel:kubic:libcontainers:stable:podman-desktop.repo"

dnf5 check-update

# Install all defined packages from the enabled repositories
dnf5 install -y ${packages_to_install[@]}

# move ot to /user/lib and symlink to /usr/bin

mv /opt/google/chrome-beta /usr/lib/google-chrome-beta && \
    ln -sf /usr/lib/google-chrome-beta/google-chrome-beta /usr/bin/google-chrome-beta


check_empty "${EMPTY_DIRS[@]}"

## -- CLEANUP -- ##


## -- TESTING -- ##
test -x /usr/lib/google-chrome-beta/google-chrome-beta || echo "chrome-binary missing"
test -L /usr/bin/google-chrome-beta || echo "chrome symlink missing"
