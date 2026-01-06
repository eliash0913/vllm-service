#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/vllm/vllm.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
fi

VLLM_MODEL="${VLLM_MODEL:-}"
if [[ -z "${VLLM_MODEL}" ]]; then
  echo "ERROR: VLLM_MODEL is not set. Configure it in ${ENV_FILE}." >&2
  exit 1
fi

VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_ARGS="${VLLM_ARGS:-}"

PYTHON_BIN="/opt/vllm/venv/bin/python"
if [[ ! -x "${PYTHON_BIN}" ]]; then
  PYTHON_BIN="$(command -v python3)"
fi

read -r -a EXTRA_ARGS <<< "${VLLM_ARGS}"

exec "${PYTHON_BIN}" -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --model "${VLLM_MODEL}" \
  "${EXTRA_ARGS[@]}"
