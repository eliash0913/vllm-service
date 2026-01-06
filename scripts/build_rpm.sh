#!/usr/bin/env bash
set -euo pipefail

VERSION="0.11.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
WHEELHOUSE_DIR="${ARTIFACTS_DIR}/wheelhouse"
STAGE_DIR="${ARTIFACTS_DIR}/stage"
BUILD_DIR="${ARTIFACTS_DIR}/build"
PKG_DIR="${ARTIFACTS_DIR}/packages/rpm"
SPEC_FILE="${ROOT_DIR}/packaging/vllm.spec"
ENV_FILE="${ROOT_DIR}/packaging/vllm.env"
SERVICE_FILE="${ROOT_DIR}/systemd/vllm.service"
RUN_SCRIPT="${ROOT_DIR}/scripts/run_vllm.sh"

mkdir -p "${WHEELHOUSE_DIR}" "${STAGE_DIR}" "${BUILD_DIR}" "${PKG_DIR}"

if [[ -z "$(ls -A "${WHEELHOUSE_DIR}" 2>/dev/null || true)" ]]; then
  echo "ERROR: wheelhouse is empty. Run ./scripts/download_dependencies.sh first." >&2
  exit 1
fi

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/opt/vllm/bin" "${STAGE_DIR}/etc/vllm" "${STAGE_DIR}/usr/lib/systemd/system"

if [[ -z "${PYTHON_BIN:-}" ]]; then
  if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN="python3.12"
  else
    PYTHON_BIN="python3"
  fi
fi

"${PYTHON_BIN}" -m venv "${STAGE_DIR}/opt/vllm/venv"
if [[ "${PIP_UPGRADE:-0}" == "1" ]]; then
  "${STAGE_DIR}/opt/vllm/venv/bin/python" -m pip install --upgrade pip
fi
"${STAGE_DIR}/opt/vllm/venv/bin/pip" install --no-index --find-links "${WHEELHOUSE_DIR}" "vllm==${VERSION}"

mkdir -p "${STAGE_DIR}/opt/vllm/wheelhouse"
cp -a "${WHEELHOUSE_DIR}/." "${STAGE_DIR}/opt/vllm/wheelhouse/"

install -m 0755 "${RUN_SCRIPT}" "${STAGE_DIR}/opt/vllm/bin/run_vllm.sh"
install -m 0644 "${ENV_FILE}" "${STAGE_DIR}/etc/vllm/vllm.env"
install -m 0644 "${SERVICE_FILE}" "${STAGE_DIR}/usr/lib/systemd/system/vllm.service"

TARBALL="${BUILD_DIR}/vllm-service-${VERSION}.tar.gz"
tar -C "${STAGE_DIR}" -czf "${TARBALL}" .

RPMBUILD_DIR="${BUILD_DIR}/rpmbuild"
mkdir -p "${RPMBUILD_DIR}/"{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cp "${SPEC_FILE}" "${RPMBUILD_DIR}/SPECS/"
cp "${TARBALL}" "${RPMBUILD_DIR}/SOURCES/"

rpmbuild --define "_topdir ${RPMBUILD_DIR}" -bb "${RPMBUILD_DIR}/SPECS/vllm.spec"

find "${RPMBUILD_DIR}/RPMS" -name "*.rpm" -exec cp {} "${PKG_DIR}/" \;
echo "RPM packages written to ${PKG_DIR}"
