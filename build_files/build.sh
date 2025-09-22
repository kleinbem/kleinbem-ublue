#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket


### my changes

# Enable Google Chrome repo
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/google-chrome.repo


#todo:
# - move to base image
#Podman Desktop (io.podman_desktop.PodmanDesktop)
#Cockpit Client (org.cockpit_project.CockpitClient)
#GNOME Builder (org.gnome.Builder)
#Arduino IDE (cc.arduino.IDE2)
#Sysd Manager (io.github.plrigaux.sysd-manager)
#DevToolbox (me.iepure.devtoolbox)
# - maybe move to base image
#Geany (org.geany.Geany)
#DBeaver (io.dbeaver.DBeaverCommunity)
#GitKraken (com.axosoft.GitKraken)
#LACT (io.github.ilya_zlobintsev.LACT)
#Solaar (io.github.pwr_solaar.solaar)

# Packages

base_packages=(
  "google-chrome-beta"
)

utility_packages=(
  "scrcpy"
)

packages=(
  ${base_packages[@]}
  ${utility_packages[@]}
)

# install rpms
dnf5 install -y ${packages[@]}

