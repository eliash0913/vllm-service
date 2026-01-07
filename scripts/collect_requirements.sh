#!/usr/bin/env bash
set -euo pipefail

VERSION="${VLLM_VERSION:-0.11.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
REQ_DIR="${ARTIFACTS_DIR}/requirements"

mkdir -p "${REQ_DIR}"

INSTALL=false
if [[ "${1:-}" == "--install" ]]; then
  INSTALL=true
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "ERROR: /etc/os-release not found; cannot detect distro." >&2
  exit 1
fi

ID_LIKE_VALUE="${ID_LIKE:-}"
REQ_FILE="${REQ_DIR}/${ID}-${VERSION_ID}.txt"

common_pkgs=(
  git
  python3
  python3-pip
  cmake
  ninja-build
  pkg-config
)

rpm_pkgs=(
  gcc
  gcc-c++
  make
  python3-devel
  openssl-devel
  libffi-devel
  zlib-devel
  rpm-build
)

deb_pkgs=(
  build-essential
  python3-dev
  python3-venv
  libssl-dev
  libffi-dev
  zlib1g-dev
)

optional_rpm_pkgs=(
  ninja-build
  patchelf
)

optional_deb_pkgs=(
  patchelf
)

if [[ "${ID}" == "rhel" || "${ID}" == "centos" || "${ID}" == "rocky" || "${ID}" == "almalinux" || "${ID_LIKE_VALUE}" == *"rhel"* ]]; then
  reqs=("${common_pkgs[@]}" "${rpm_pkgs[@]}")
  pkg_manager="dnf"
  if ! command -v dnf >/dev/null 2>&1; then
    pkg_manager="yum"
  fi
elif [[ "${ID}" == "ubuntu" || "${ID}" == "debian" || "${ID_LIKE_VALUE}" == *"debian"* ]]; then
  reqs=("${common_pkgs[@]}" "${deb_pkgs[@]}")
  pkg_manager="apt-get"
else
  echo "ERROR: Unsupported distro ID: ${ID}" >&2
  exit 1
fi

{
  echo "# Build requirements for vllm ${VERSION} on ${ID} ${VERSION_ID}"
  printf "%s\n" "${reqs[@]}"
} > "${REQ_FILE}"

echo "Wrote requirements to ${REQ_FILE}"

if [[ "${INSTALL}" == "true" ]]; then
  echo "Installing requirements using ${pkg_manager}..."
  sudo_cmd="sudo"
  if [[ "$(id -u)" -eq 0 ]]; then
    sudo_cmd=""
  fi
  if [[ "${pkg_manager}" == "apt-get" ]]; then
    ${sudo_cmd} apt-get update
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y "${reqs[@]}"
    for pkg in "${optional_deb_pkgs[@]}"; do
      ${sudo_cmd} apt-get install -y "${pkg}" || echo "Optional package not available: ${pkg}"
    done
  else
    if command -v dnf >/dev/null 2>&1; then
      ${sudo_cmd} dnf -y install dnf-plugins-core || true
      if [[ "${VERSION_ID}" == 8* ]]; then
        ${sudo_cmd} dnf config-manager --set-enabled powertools || true
      elif [[ "${VERSION_ID}" == 9* ]]; then
        ${sudo_cmd} dnf config-manager --set-enabled crb || true
      fi
    fi
    ${sudo_cmd} "${pkg_manager}" install -y "${reqs[@]}"
    for pkg in "${optional_rpm_pkgs[@]}"; do
      ${sudo_cmd} "${pkg_manager}" install -y "${pkg}" || echo "Optional package not available: ${pkg}"
    done
  fi
fi
