#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
#  btcsr8510 APT repo builder (multi-arch, multi-distro)
#  Generates full APT repository with proper signed Release,
#  InRelease, Packages, pool/, etc.
#
#  Example:
#     ./repo-build.sh --key F2428D206691101B631E3DC48EC554F17BECD88A
# ==========================================================

KEYID=""
DEB="btcsr8510_2025.01_all.deb"
DISTS="kali-rolling debian-bookworm ubuntu-jammy ubuntu-noble parrot"
COMP="main"
PKG="btcsr8510"
ARCH="all"   # deb is arch-independent

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEYID="$2"; shift 2;;
    --deb) DEB="$2"; shift 2;;
    --dists) DISTS="$2"; shift 2;;
    --component) COMP="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done

[[ -z "$KEYID" ]] && { echo "ERROR: --key <KEYID> required"; exit 1; }
[[ ! -f "$DEB" ]] && { echo "ERROR: .deb missing: $DEB"; exit 1; }

command -v apt-ftparchive >/dev/null || { echo "Install apt-utils"; exit 1; }
command -v dpkg-scanpackages >/dev/null || { echo "Install dpkg-dev"; exit 1; }

echo "[*] Cleaning current repo (gh-pages working tree)…"
git rm -rf . >/dev/null 2>&1 || true
rm -rf ./* ./.??* 2>/dev/null || true

# pool structure
POOL="pool/${COMP}/b/${PKG}"
mkdir -p "${POOL}"
cp -f "../${DEB}" "${POOL}/"

# copy helper files from main
for f in install.sh key.gpg LICENSE README.md; do
  [[ -f "../$f" ]] && cp -f "../$f" .
done

# --- Build Packages index (once, reused per distro)
PKGTMP="dists/_tmp/${COMP}/binary-${ARCH}"
mkdir -p "${PKGTMP}"
( dpkg-scanpackages --arch ${ARCH} "pool/${COMP}" ) > "${PKGTMP}/Packages"
gzip -9c "${PKGTMP}/Packages" > "${PKGTMP}/Packages.gz"

# --- Loop each distro
for DIST in ${DISTS}; do
  echo "[*] Building APT metadata for ${DIST}…"

  DEST="dists/${DIST}/${COMP}/binary-${ARCH}"
  mkdir -p "${DEST}"
  cp -f "${PKGTMP}/Packages"    "${DEST}/"
  cp -f "${PKGTMP}/Packages.gz" "${DEST}/"

  # apt-ftparchive config
  CFG="dists/${DIST}/apt-ftparchive.conf"
  mkdir -p "dists/${DIST}"
  cat > "${CFG}" <<EOF
Dir {
  ArchiveDir ".";
};

TreeDefault {
  Directory "dists/${DIST}";
};

Default {
  Packages::Compress ". gzip";
};

APT::FTPArchive::Release {
  Origin "btcsr8510";
  Label "btcsr8510";
  Suite "${DIST}";
  Codename "${DIST}";
  Architectures "${ARCH}";
  Components "${COMP}";
  Description "CSR8510 firmware autoloader repo";
};
EOF

  # Create unsigned Release
  apt-ftparchive -c "${CFG}" release "dists/${DIST}" > "dists/${DIST}/Release"

  # Sign Release
  gpg --batch --yes -u "${KEYID}" -abs \
      -o "dists/${DIST}/Release.gpg" "dists/${DIST}/Release"
  gpg --batch --yes -u "${KEYID}" --clearsign \
      -o "dists/${DIST}/InRelease"  "dists/${DIST}/Release"
done

echo "[✔] APT repo successfully built."
echo "[→] Now run: git add . && git commit && git push -f origin gh-pages"
