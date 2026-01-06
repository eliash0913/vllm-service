#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/vllm.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
SERVICE_NAME="${SERVICE_NAME:-vservice}"
SERVICE_VERSION="${SERVICE_VERSION:-}"
ENV_NAME="${CONDA_ENV_NAME:-vllm}"
PYTHON_VERSION="${CONDA_PYTHON_VERSION:-3.11}"
MINICONDA_PREFIX="${MINICONDA_PREFIX:-$HOME/miniconda3}"
VLLM_VERSION="${VLLM_VERSION:-}"
if [[ -z "${PACK_OUTPUT:-}" ]]; then
  if [[ -n "${SERVICE_VERSION}" ]]; then
    PACK_OUTPUT="${ARTIFACTS_DIR}/${SERVICE_NAME}-${SERVICE_VERSION}.tar.gz"
  else
    PACK_OUTPUT="${ARTIFACTS_DIR}/${SERVICE_NAME}.tar.gz"
  fi
fi

if [[ ! -f "${MINICONDA_PREFIX}/etc/profile.d/conda.sh" ]]; then
  echo "Miniconda not found at ${MINICONDA_PREFIX}" >&2
  echo "Install it with ./scripts/install_miniconda.sh or set MINICONDA_PREFIX." >&2
  exit 1
fi

mkdir -p "${ARTIFACTS_DIR}"

# shellcheck source=/dev/null
source "${MINICONDA_PREFIX}/etc/profile.d/conda.sh"

if ! conda info >/dev/null 2>&1; then
  echo "Failed to initialize conda from ${MINICONDA_PREFIX}" >&2
  exit 1
fi

if ! conda env list | awk '{print $1}' | grep -Fxq "${ENV_NAME}"; then
  conda create -y -n "${ENV_NAME}" "python=${PYTHON_VERSION}"
fi

conda activate "${ENV_NAME}"

if ! conda list -n "${ENV_NAME}" conda-pack | awk 'NR>2 {print $1}' | grep -Fxq conda-pack; then
  conda install -y -n "${ENV_NAME}" conda-pack
fi

if [[ -n "${VLLM_VERSION}" ]]; then
  python -m pip install "vllm==${VLLM_VERSION}"
else
  python -m pip install vllm
fi

conda pack -n "${ENV_NAME}" -o "${PACK_OUTPUT}"

echo "Packed ${SERVICE_NAME} environment written to ${PACK_OUTPUT}"
