#!/bin/bash
set -euo pipefail
set -x

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

# --- SYSTEM CONFIG ---
systemctl enable podman.socket || true

# --- REPOS ---
# Chrome (Bluefin ships google-chrome.repo; there is NO google-chrome-beta.repo file)
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/google-chrome.repo || true

# VS Code repo (covers BOTH stable `code` and `code-insiders`)
# If vscode.repo exists, enable it; otherwise drop official config.repo
if [[ -f /etc/yum.repos.d/vscode.repo ]]; then
  sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/vscode.repo || true
else
  curl -fsSL https://packages.microsoft.com/yumrepos/vscode/config.repo \
    -o /etc/yum.repos.d/vscode.repo
fi

# Negativo17 multimedia + priority
if [[ -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo ]]; then
  sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo || true
  grep -q '^priority=90$' /etc/yum.repos.d/negativo17-fedora-multimedia.repo || \
    echo 'priority=90' >> /etc/yum.repos.d/negativo17-fedora-multimedia.repo
fi

# RPM Fusion priorities (append only once)
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
  [[ -f "$f" ]] || continue
  grep -q '^priority=99$' "$f" || echo 'priority=99' >> "$f"
done

# Manually create the directory for Google Chrome before installation
mkdir -p /var/opt/google/chrome-beta

# --- DOWNLOADS ---
# Scrape the NoMachine website to find the URL for the latest 64-bit RPM
echo "Fetching the latest NoMachine URL..."
BASE_URL="https://www.nomachine.com"
DOWNLOAD_PAGE_URL="${BASE_URL}/download/linux"

# This command finds the relative path to the RPM and builds the full URL
# It uses grep with a Perl-compatible regex (-P) to extract just the link
# The script will fail here if the URL can't be found (due to `set -o pipefail`)
LATEST_PATH=$(curl -sL "${DOWNLOAD_PAGE_URL}" | grep -oP 'href="\K[^"]*x86_64\.rpm' | head -n 1)
NOMACHINE_URL="${BASE_URL}${LATEST_PATH}"

echo "Latest NoMachine URL is: ${NOMACHINE_URL}"

# Download the NoMachine RPM to a temporary location
NOMACHINE_RPM="/tmp/$(basename "${NOMACHINE_URL}")"
curl -fL "${NOMACHINE_URL}" -o "${NOMACHINE_RPM}"

# --- PACKAGES ---
# Bash arrays: no commas, no stray quotes, no "code!" typo
base_packages=(
  dnf5-plugins
  google-chrome-beta
  code
  code-insiders
  xpra
)

utility_packages=(
  # add extra tools here
)

# Add the downloaded NoMachine RPM to the list of packages to install
packages_to_install=("${base_packages[@]}" "${utility_packages[@]}" "${NOMACHINE_RPM}")

dnf5 clean all
dnf5 makecache
dnf5 -y install "${packages_to_install[@]}"

# --- CLEANUP ---
# Remove the downloaded NoMachine RPM after installation
rm -f "${NOMACHINE_RPM}"

# move Chrome Beta out of /opt into /usr/lib
rm -rf /usr/lib/google-chrome-beta
mv /opt/google/chrome-beta /usr/lib/google-chrome-beta

# symlink to /usr/bin so it's in $PATH
ln -sf /usr/lib/google-chrome-beta/google-chrome-beta /usr/bin/google-chrome-beta

# --- TESTS ---
check_empty "${EMPTY_DIRS[@]}"
command -v google-chrome-beta >/dev/null || echo "chrome-binary missing"
command -v code >/dev/null || echo "code missing"
command -v code-insiders >/dev/null || echo "code-insiders missing"
test -f /usr/NX/bin/nxplayer || echo "nomachine (nxplayer) missing"