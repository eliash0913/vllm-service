#!/usr/bin/env bash
set -euo pipefail

VERSION="0.11.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
WHEELHOUSE_DIR="${ARTIFACTS_DIR}/wheelhouse"
STAGE_DIR="${ARTIFACTS_DIR}/stage-deb"
PKG_DIR="${ARTIFACTS_DIR}/packages/deb"
ENV_FILE="${ROOT_DIR}/packaging/vllm.env"
SERVICE_FILE="${ROOT_DIR}/systemd/vllm.service"
RUN_SCRIPT="${ROOT_DIR}/scripts/run_vllm.sh"

mkdir -p "${WHEELHOUSE_DIR}" "${PKG_DIR}"

run_with_heartbeat() {
  local label="$1"
  shift
  local interval="${HEARTBEAT_INTERVAL:-60}"
  local start_ts
  start_ts="$(date +%s)"

  "$@" &
  local cmd_pid=$!
  while kill -0 "${cmd_pid}" 2>/dev/null; do
    local now_ts
    now_ts="$(date +%s)"
    local elapsed=$((now_ts - start_ts))
    echo "[${label}] still running... ${elapsed}s elapsed"
    sleep "${interval}"
  done
  wait "${cmd_pid}"
}

if [[ -z "$(ls -A "${WHEELHOUSE_DIR}" 2>/dev/null || true)" ]]; then
  echo "ERROR: wheelhouse is empty. Run ./scripts/download_dependencies.sh first." >&2
  exit 1
fi

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/opt/vllm/bin" "${STAGE_DIR}/etc/vllm" "${STAGE_DIR}/usr/lib/systemd/system" "${STAGE_DIR}/DEBIAN"

if [[ -z "${PYTHON_BIN:-}" ]]; then
  if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN="python3.12"
  else
    PYTHON_BIN="python3"
  fi
fi

"${PYTHON_BIN}" -m venv "${STAGE_DIR}/opt/vllm/venv"
if [[ "${PIP_UPGRADE:-0}" == "1" ]]; then
  run_with_heartbeat "pip-upgrade" "${STAGE_DIR}/opt/vllm/venv/bin/python" -m pip install --upgrade pip
fi
run_with_heartbeat "pip-install" "${STAGE_DIR}/opt/vllm/venv/bin/pip" install --no-index --find-links "${WHEELHOUSE_DIR}" "vllm==${VERSION}"

mkdir -p "${STAGE_DIR}/opt/vllm/wheelhouse"
cp -a "${WHEELHOUSE_DIR}/." "${STAGE_DIR}/opt/vllm/wheelhouse/"

install -m 0755 "${RUN_SCRIPT}" "${STAGE_DIR}/opt/vllm/bin/run_vllm.sh"
install -m 0644 "${ENV_FILE}" "${STAGE_DIR}/etc/vllm/vllm.env"
install -m 0644 "${SERVICE_FILE}" "${STAGE_DIR}/usr/lib/systemd/system/vllm.service"

cat > "${STAGE_DIR}/DEBIAN/control" <<EOF
Package: vllm-service
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: amd64
Maintainer: vllm packaging <packaging@example.com>
Depends: python3, systemd
Description: vLLM service daemon
 Packages vLLM with a systemd service wrapper.
EOF

cat > "${STAGE_DIR}/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env bash
set -e
if ! getent group vllm >/dev/null; then
  groupadd --system vllm
fi
if ! getent passwd vllm >/dev/null; then
  useradd --system --gid vllm --shell /usr/sbin/nologin --home /opt/vllm vllm
fi
systemctl daemon-reload
systemctl enable vllm.service >/dev/null 2>&1 || true
EOF

cat > "${STAGE_DIR}/DEBIAN/postrm" <<'EOF'
#!/usr/bin/env bash
set -e
systemctl daemon-reload
EOF

cat > "${STAGE_DIR}/DEBIAN/conffiles" <<EOF
/etc/vllm/vllm.env
EOF

chmod 0755 "${STAGE_DIR}/DEBIAN/postinst" "${STAGE_DIR}/DEBIAN/postrm"

OUTPUT="${PKG_DIR}/vllm-service_${VERSION}-1_amd64.deb"
run_with_heartbeat "dpkg-deb" dpkg-deb --build "${STAGE_DIR}" "${OUTPUT}"

echo "DEB package written to ${OUTPUT}"
