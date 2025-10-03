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
echo "Resolving latest NoMachine RPM URL..."
NOMACHINE_URL="$(
python3 - <<'PY' || exit 1
import re,requests,sys
U="https://download.nomachine.com/download/?id=1&platform=linux"
RX1=re.compile(r'https://web\d+\.nomachine\.com/download/\d+(?:\.\d+)*/Linux/nomachine_[\d._-]+_x86_64\.rpm')
RX2=re.compile(r'class="path"\s+value="(https://[^"]*_x86_64\.rpm)"')
s=requests.Session();s.headers.update({'User-Agent':'Mozilla/5.0','Referer':'https://www.nomachine.com/download'})
for _ in range(3):
    h=s.get(U,timeout=15,allow_redirects=True).text
    L=RX1.findall(h) or RX2.findall(h)
    if L:
        print(sorted(set(L),key=lambda u:tuple(map(int,re.findall(r'\d+',u))))[-1])
        sys.exit(0)
sys.exit(1)
PY
)" || {
  # Fallback with curl (cookie jar + UA), still extracting full URL
  ck=/tmp/nx.cookies
  NOMACHINE_URL="$(curl -fsSL -A 'Mozilla/5.0' --cookie-jar "$ck" --cookie "$ck" \
      'https://download.nomachine.com/download/?id=1&platform=linux' \
      | grep -Eo 'https://web[0-9]+\.nomachine\.com/download/[0-9.]+/Linux/nomachine_[0-9._-]+_x86_64\.rpm' \
      | sort -u -V | tail -n1)" || true
  # try <input class="path" ...>
  [[ -z "${NOMACHINE_URL}" ]] && NOMACHINE_URL="$(curl -fsSL -A 'Mozilla/5.0' --cookie-jar "$ck" --cookie "$ck" \
      'https://download.nomachine.com/download/?id=1&platform=linux' \
      | sed -n 's/.*class="path" value="\([^"]*_x86_64\.rpm\)".*/\1/p' \
      | sort -u -V | tail -n1)"
}
[[ -z "${NOMACHINE_URL}" ]] && { echo "Error: NoMachine URL not found"; exit 1; }
echo "NoMachine URL: ${NOMACHINE_URL}"

# Download the NoMachine RPM to a temporary location
NOMACHINE_RPM="/tmp/$(basename "${NOMACHINE_URL}")"
curl -fL --retry 3 -o "${NOMACHINE_RPM}" "${NOMACHINE_URL}"

# --- PACKAGES ---
# Bash arrays: no commas, no stray quotes, no "code!" typo
base_packages=(
  dnf5-plugins
  google-chrome-beta
  code
  code-insiders
  waypipe
  btop
  htop
  stress-ng
  pesign
  sbsigntools
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
command -v ansible >/dev/null || echo "ansible missing"
