
### `repo-build.sh` (local helper to build metadata; CI will do this too)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Inputs
DEB_FILE="${1:-btcsr8510_2025.01_all.deb}"
KEYID="${2:-}"   # optional if you want to sign locally

if [[ ! -f "$DEB_FILE" ]]; then
  echo "Missing $DEB_FILE"; exit 1
fi

# Repo layout
ROOT="$(pwd)"
OUT="$ROOT/site"
POOL="$OUT/pool/main/b/btcsr8510"
DISTROS=("kali-rolling" "bookworm" "jammy" "noble" "parrot")

rm -rf "$OUT"
mkdir -p "$POOL"

# Copy package into pool
cp -f "$DEB_FILE" "$POOL/"

# Create dists/*/Packages(.gz) and Release files
for D in "${DISTROS[@]}"; do
  BINDIR="$OUT/dists/$D/main/binary-all"
  mkdir -p "$BINDIR"
  ( cd "$OUT" && dpkg-scanpackages --arch all pool ) > "$BINDIR/Packages"
  gzip -f9 < "$BINDIR/Packages" > "$BINDIR/Packages.gz"

  # Minimal Release
  cat > "$OUT/dists/$D/Release" <<EOF
Origin: btcsr8510
Label: btcsr8510
Suite: $D
Codename: $D
Architectures: all
Components: main
Date: $(LC_ALL=C date -Ru)
EOF

  # If signing locally:
  if [[ -n "$KEYID" ]]; then
    gpg --yes -u "$KEYID" --output "$OUT/dists/$D/Release.gpg" -ba "$OUT/dists/$D/Release"
    gpg --yes -u "$KEYID" --output "$OUT/dists/$D/InRelease" --clearsign "$OUT/dists/$D/Release"
  fi
done

# Export public key if local signing
if [[ -n "$KEYID" ]]; then
  gpg --export --armor "$KEYID" > "$OUT/key.gpg"
fi

echo "Repo staged in: $OUT"
