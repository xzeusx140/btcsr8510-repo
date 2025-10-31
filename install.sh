#!/usr/bin/env bash
set -euo pipefail

REPO_USER="xzeusx140"
REPO_NAME="btcsr8510-repo"
KEY_URL="https://$REPO_USER.github.io/$REPO_NAME/key.gpg"

# Map distro → codename used in this repo
detect_codename() {
  . /etc/os-release
  case "${ID}-${VERSION_CODENAME:-}" in
    kali-rolling) echo "kali-rolling" ;;
    debian-bookworm) echo "bookworm" ;;
    ubuntu-jammy) echo "jammy" ;;
    ubuntu-noble) echo "noble" ;;
    parrot-rolling) echo "parrot" ;;
    *) 
      # fallback for Kali-derived or unknown → use kali-rolling
      if [[ "${ID:-}" == "kali" ]]; then echo "kali-rolling"; else echo "kali-rolling"; fi
      ;;
  esac
}

CODENAME="$(detect_codename)"

# Install repo key
sudo mkdir -p /usr/share/keyrings
curl -fsSL "$KEY_URL" | sudo gpg --dearmor -o /usr/share/keyrings/btcsr8510.gpg

# Add source list
echo "deb [signed-by=/usr/share/keyrings/btcsr8510.gpg] https://$REPO_USER.github.io/$REPO_NAME $CODENAME main" | \
  sudo tee /etc/apt/sources.list.d/btcsr8510.list >/dev/null

# Update & install
sudo apt update
sudo apt install -y btcsr8510

echo "btcsr8510 installed. Run: sudo csr-fw-manager"
