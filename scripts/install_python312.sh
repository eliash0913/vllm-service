#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.12.11"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
SRC_DIR="${ARTIFACTS_DIR}/python-src"
PREFIX="/opt/python/${PYTHON_VERSION}"

PYTHON_BIN="${PREFIX}/bin/python3.12"

if [[ -x "${PYTHON_BIN}" ]]; then
  installed_ver="$("${PYTHON_BIN}" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  if [[ "${installed_ver}" == "${PYTHON_VERSION}" ]]; then
    echo "Python ${PYTHON_VERSION} already installed at ${PYTHON_BIN}"
    if [[ "${PIP_UPGRADE:-0}" == "1" ]]; then
      "${PYTHON_BIN}" -m pip install --upgrade pip
    fi
    exit 0
  fi
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "ERROR: /etc/os-release not found; cannot detect distro." >&2
  exit 1
fi

install_build_deps_rpm() {
  dnf -y install dnf-plugins-core || true
  if [[ "${VERSION_ID}" == 8* ]]; then
    dnf config-manager --set-enabled powertools || true
  elif [[ "${VERSION_ID}" == 9* ]]; then
    dnf config-manager --set-enabled crb || true
  fi
  dnf -y install epel-release || true
  dnf -y install \
    gcc gcc-c++ make \
    bzip2 bzip2-devel \
    openssl openssl-devel \
    libffi libffi-devel \
    zlib zlib-devel \
    readline readline-devel \
    sqlite sqlite-devel \
    xz xz-devel \
    ncurses ncurses-devel \
    gdbm gdbm-devel \
    libuuid libuuid-devel \
    tk tk-devel \
    wget tar
}

install_build_deps_deb() {
  env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update
  env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
    build-essential \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev \
    wget \
    tar
}

if [[ "${ID}" == "rhel" || "${ID}" == "centos" || "${ID}" == "rocky" || "${ID}" == "almalinux" || "${ID_LIKE:-}" == *"rhel"* ]]; then
  install_build_deps_rpm
elif [[ "${ID}" == "ubuntu" || "${ID}" == "debian" || "${ID_LIKE:-}" == *"debian"* ]]; then
  install_build_deps_deb
else
  echo "ERROR: Unsupported distro ID: ${ID}" >&2
  exit 1
fi

mkdir -p "${SRC_DIR}"
TARBALL="${SRC_DIR}/Python-${PYTHON_VERSION}.tgz"

if [[ ! -f "${TARBALL}" ]]; then
  echo "Downloading Python ${PYTHON_VERSION} source..."
  wget -O "${TARBALL}" "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
fi

rm -rf "${SRC_DIR}/Python-${PYTHON_VERSION}"
tar -C "${SRC_DIR}" -xzf "${TARBALL}"

pushd "${SRC_DIR}/Python-${PYTHON_VERSION}" >/dev/null
./configure --prefix="${PREFIX}" --enable-optimizations --with-ensurepip=install
make -j"$(getconf _NPROCESSORS_ONLN)"
make install
popd >/dev/null

if [[ "${PIP_UPGRADE:-0}" == "1" ]]; then
  "${PYTHON_BIN}" -m pip install --upgrade pip
fi

echo "Installed Python ${PYTHON_VERSION} at ${PYTHON_BIN}"
