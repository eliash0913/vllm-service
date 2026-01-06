#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/vllm.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

PREFIX="${MINICONDA_PREFIX:-$HOME/miniconda3}"
INSTALLER_URL="${MINICONDA_INSTALLER_URL:-}"

if [[ -x "${PREFIX}/bin/conda" ]]; then
  echo "Miniconda already installed at ${PREFIX}"
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ -z "${INSTALLER_URL}" ]]; then
  case "${OS}-${ARCH}" in
    Linux-x86_64)
      INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
      ;;
    Linux-aarch64)
      INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
      ;;
    Darwin-x86_64)
      INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
      ;;
    Darwin-arm64)
      INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
      ;;
    *)
      echo "Unsupported OS/arch combination: ${OS} ${ARCH}" >&2
      echo "Set MINICONDA_INSTALLER_URL to override." >&2
      exit 1
      ;;
  esac
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
INSTALLER_PATH="${TMP_DIR}/miniconda.sh"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${INSTALLER_URL}" -o "${INSTALLER_PATH}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${INSTALLER_PATH}" "${INSTALLER_URL}"
else
  echo "Neither curl nor wget is available to download Miniconda." >&2
  exit 1
fi

bash "${INSTALLER_PATH}" -b -p "${PREFIX}"

echo "Miniconda installed at ${PREFIX}"
echo "Run: ${PREFIX}/bin/conda init"
