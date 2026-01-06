#!/usr/bin/env bash
set -euo pipefail

VERSION="0.11.0+cu129"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
WHEELHOUSE_DIR="${ARTIFACTS_DIR}/wheelhouse"

mkdir -p "${WHEELHOUSE_DIR}"

if [[ -z "${PYTHON_BIN:-}" ]]; then
  if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN="python3.12"
  else
    PYTHON_BIN="python3"
  fi
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "ERROR: ${PYTHON_BIN} not found." >&2
  exit 1
fi

PYTHON_DIR="$(dirname "${PYTHON_BIN}")"
export PATH="${PYTHON_DIR}:${PATH}"
export PYTHON="${PYTHON_BIN}"
export Python3_EXECUTABLE="${PYTHON_BIN}"
if [[ -n "${CMAKE_ARGS:-}" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DPython3_EXECUTABLE=${PYTHON_BIN}"
else
  export CMAKE_ARGS="-DPython3_EXECUTABLE=${PYTHON_BIN}"
fi

if [[ "${PIP_UPGRADE:-0}" == "1" ]]; then
  "${PYTHON_BIN}" -m pip install --upgrade pip
fi

CPU_COUNT="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
MEM_AVAILABLE_KB="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
if [[ "${MEM_AVAILABLE_KB}" -gt 0 ]]; then
  MEM_AVAILABLE_GB="$((MEM_AVAILABLE_KB / 1024 / 1024))"
else
  MEM_AVAILABLE_GB=0
fi
if [[ "${MEM_AVAILABLE_GB}" -gt 0 ]]; then
  # Roughly cap parallelism to ~2GB per job to avoid OOM during builds.
  MEM_LIMITED_JOBS="$((MEM_AVAILABLE_GB / 2))"
else
  MEM_LIMITED_JOBS="${CPU_COUNT}"
fi
if [[ "${MEM_LIMITED_JOBS}" -lt 1 ]]; then
  MEM_LIMITED_JOBS=1
fi
if [[ "${MEM_LIMITED_JOBS}" -gt "${CPU_COUNT}" ]]; then
  MEM_LIMITED_JOBS="${CPU_COUNT}"
fi
if [[ -z "${NVCC_THREADS:-}" ]]; then
  export NVCC_THREADS="1"
fi
if [[ -z "${CMAKE_BUILD_PARALLEL_LEVEL:-}" ]]; then
  export CMAKE_BUILD_PARALLEL_LEVEL="${MEM_LIMITED_JOBS}"
fi
if [[ -z "${MAX_JOBS:-}" ]]; then
  export MAX_JOBS="${MEM_LIMITED_JOBS}"
fi

if [[ "${VLLM_DISABLE_MARLIN:-0}" == "1" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DVLLM_USE_MARLIN=OFF -DVLLM_ENABLE_MARLIN=OFF -DVLLM_BUILD_MARLIN=OFF"
fi

if [[ -n "${CUDA_HOME:-}" ]]; then
  export PATH="${CUDA_HOME}/bin:${PATH}"
  export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
fi

if [[ -z "${TORCH_CUDA_ARCH_LIST:-}" ]]; then
  export TORCH_CUDA_ARCH_LIST="8.9"
fi

if [[ "${VLLM_BUILD_FROM_SOURCE:-0}" == "1" ]]; then
  if [[ -z "${CUDA_HOME:-}" ]]; then
    echo "ERROR: VLLM_BUILD_FROM_SOURCE=1 requires CUDA_HOME to be set." >&2
    exit 1
  fi
  echo "Building vllm ${VERSION} from source into wheelhouse at ${WHEELHOUSE_DIR}..."
  "${PYTHON_BIN}" -m pip wheel --wheel-dir "${WHEELHOUSE_DIR}" --no-binary vllm "vllm==${VERSION}"
else
  echo "Downloading vllm ${VERSION} and dependencies to ${WHEELHOUSE_DIR}..."
  "${PYTHON_BIN}" -m pip download --dest "${WHEELHOUSE_DIR}" "vllm==${VERSION}"
fi
echo "Download complete."
