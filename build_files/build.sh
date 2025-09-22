#!/bin/bash

# This script is designed to be idempotent and can be run safely multiple times.
set -ouex pipefail

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

# Define lists of packages to install
# This makes it easy to manage and see what's being added.
base_packages=(
  "google-chrome-beta"
)

utility_packages=(
  "scrcpy"
)

# Combine all package lists into one
packages_to_install=(
  ${base_packages[@]}
  ${utility_packages[@]}
)

# Install all defined packages from the enabled repositories
dnf5 install -y ${packages_to_install[@]}

## -- TODO for your base image -- ##
# The following are your notes on packages to consider moving into your
# declarative build file for a truly custom base image.

# High-priority candidates:
# Podman Desktop, Cockpit Client, GNOME Builder, Arduino IDE,
# Sysd Manager, DevToolbox

# Lower-priority candidates (depends on workflow):
# Geany, DBeaver, GitKraken, LACT, Solaar