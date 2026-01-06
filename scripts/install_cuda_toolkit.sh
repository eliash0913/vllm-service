#!/usr/bin/env bash
set -euo pipefail

CUDA_MAJOR_MINOR="${CUDA_MAJOR_MINOR:-12-9}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "ERROR: /etc/os-release not found; cannot detect distro." >&2
  exit 1
fi

install_cuda_rpm() {
  local repo_url=""
  if [[ "${VERSION_ID}" == 8* ]]; then
    repo_url="https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo"
  elif [[ "${VERSION_ID}" == 9* ]]; then
    repo_url="https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo"
  else
    echo "ERROR: Unsupported RHEL/Rocky version: ${VERSION_ID}" >&2
    exit 1
  fi

  dnf -y install dnf-plugins-core || true
  dnf config-manager --add-repo "${repo_url}"
  dnf -y install "cuda-toolkit-${CUDA_MAJOR_MINOR}"
}

install_cuda_deb() {
  local ubuntu_ver="${VERSION_ID//./}"
  local repo_base="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${ubuntu_ver}/x86_64"

  apt-get update
  apt-get install -y wget gnupg ca-certificates
  wget -q -O /etc/apt/preferences.d/cuda-repository-pin-600 "${repo_base}/cuda-ubuntu${ubuntu_ver}.pin"
  wget -q -O /tmp/cuda-keyring.deb "${repo_base}/cuda-keyring_1.1-1_all.deb"
  dpkg -i /tmp/cuda-keyring.deb
  apt-get update
  apt-get install -y "cuda-toolkit-${CUDA_MAJOR_MINOR}"
}

if [[ "${ID}" == "rhel" || "${ID}" == "centos" || "${ID}" == "rocky" || "${ID}" == "almalinux" || "${ID_LIKE:-}" == *"rhel"* ]]; then
  install_cuda_rpm
elif [[ "${ID}" == "ubuntu" || "${ID}" == "debian" || "${ID_LIKE:-}" == *"debian"* ]]; then
  install_cuda_deb
else
  echo "ERROR: Unsupported distro ID: ${ID}" >&2
  exit 1
fi

if [[ -d "${CUDA_HOME}" ]]; then
  echo "CUDA toolkit installed at ${CUDA_HOME}"
else
  echo "WARNING: CUDA toolkit install completed, but ${CUDA_HOME} not found." >&2
fi
