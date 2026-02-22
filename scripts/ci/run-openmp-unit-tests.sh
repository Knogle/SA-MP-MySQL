#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build}"
MYSQL_COMPONENT_PATH="${MYSQL_COMPONENT_PATH:-${BUILD_DIR}/src/mysql.so}"
LIBMARIADB_PATH="${LIBMARIADB_PATH:-}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_USER="${DB_USER:-mysqlunittest}"
DB_PASS="${DB_PASS:-mysqlunittest}"
DB_NAME="${DB_NAME:-mysqlunittest}"

UNIT_TEST_TIMEOUT="${UNIT_TEST_TIMEOUT:-90s}"
WORK_DIR="${WORK_DIR:-/tmp/mysql-unit-test-ci}"
LOG_PATH="${WORK_DIR}/unit_test_runtime.log"
COMPILE_LOG_PATH="${WORK_DIR}/unit_test_compile.log"
SERVER_PKG_PATH="${WORK_DIR}/openmp-server.pkg"
OPENMP_SERVER_DIR="${OPENMP_SERVER_DIR:-}"
OPEN_MP_INCLUDE_DIR="${OPEN_MP_INCLUDE_DIR:-}"

mkdir -p "${WORK_DIR}"

BUILD_DIR="$(realpath -m "${BUILD_DIR}")"
MYSQL_COMPONENT_PATH="$(realpath -m "${MYSQL_COMPONENT_PATH}")"

if [[ ! -f "${MYSQL_COMPONENT_PATH}" ]]; then
	echo "ERROR: mysql component not found: ${MYSQL_COMPONENT_PATH}" >&2
	exit 1
fi

if [[ -z "${LIBMARIADB_PATH}" ]]; then
	for candidate in \
		"${BUILD_DIR}/libs/mariadb-connector-c/libmariadb/libmariadb.so.3" \
		"/usr/lib/i386-linux-gnu/libmariadb.so.3" \
		"/usr/lib/libmariadb.so.3"
	do
		if [[ -f "${candidate}" ]]; then
			LIBMARIADB_PATH="${candidate}"
			break
		fi
	done
fi

if [[ -z "${LIBMARIADB_PATH}" || ! -f "${LIBMARIADB_PATH}" ]]; then
	echo "ERROR: libmariadb.so.3 not found. Set LIBMARIADB_PATH explicitly." >&2
	exit 1
fi

if [[ -n "${OPENMP_SERVER_DIR}" ]]; then
	RUN_DIR="${OPENMP_SERVER_DIR}"
else
	OPENMP_API_URL="${OPENMP_API_URL:-https://api.github.com/repos/openmultiplayer/open.mp/releases/latest}"
	OPENMP_ASSET_REGEX="${OPENMP_ASSET_REGEX:-linux-x86.*\\.(tar\\.gz|tgz|zip)$}"

	echo "Resolving latest open.mp Linux x86 server package..."
	OMP_JSON="$(curl -fsSL "${OPENMP_API_URL}")"
	OMP_URL="$(printf '%s' "${OMP_JSON}" | jq -r --arg re "${OPENMP_ASSET_REGEX}" '.assets[] | select(.name | test($re)) | .browser_download_url' | head -n 1)"

	if [[ -z "${OMP_URL}" || "${OMP_URL}" == "null" ]]; then
		echo "ERROR: no open.mp Linux x86 package found via ${OPENMP_API_URL}" >&2
		exit 1
	fi

	rm -rf "${WORK_DIR}/openmp-extract"
	mkdir -p "${WORK_DIR}/openmp-extract"

	echo "Downloading ${OMP_URL}"
	curl -fL "${OMP_URL}" -o "${SERVER_PKG_PATH}"

	case "${OMP_URL}" in
		*.zip)
			unzip -q "${SERVER_PKG_PATH}" -d "${WORK_DIR}/openmp-extract"
			;;
		*.tar.gz|*.tgz)
			tar -xzf "${SERVER_PKG_PATH}" -C "${WORK_DIR}/openmp-extract"
			;;
		*)
			echo "ERROR: unsupported open.mp package format: ${OMP_URL}" >&2
			exit 1
			;;
	esac

	RUN_DIR="$(find "${WORK_DIR}/openmp-extract" -type f -name omp-server -printf '%h\n' | head -n 1)"
	if [[ -z "${RUN_DIR}" ]]; then
		echo "ERROR: could not locate omp-server after extraction" >&2
		exit 1
	fi
fi

if [[ ! -x "${RUN_DIR}/omp-server" ]]; then
	echo "ERROR: omp-server not executable: ${RUN_DIR}/omp-server" >&2
	exit 1
fi

PAWNCC_BIN="$(find "${RUN_DIR}" -maxdepth 3 -type f -name pawncc | head -n 1)"
if [[ -z "${PAWNCC_BIN}" ]]; then
	echo "ERROR: could not locate pawncc in ${RUN_DIR}" >&2
	exit 1
fi

if [[ -z "${OPEN_MP_INCLUDE_DIR}" ]]; then
	for candidate in \
		"${RUN_DIR}/qawno/include" \
		"${RUN_DIR}/qawno/includes" \
		"${ROOT_DIR}/qawno/include"
	do
		if [[ -d "${candidate}" ]]; then
			OPEN_MP_INCLUDE_DIR="${candidate}"
			break
		fi
	done
fi

if [[ -z "${OPEN_MP_INCLUDE_DIR}" || ! -d "${OPEN_MP_INCLUDE_DIR}" ]]; then
	echo "ERROR: open.mp include directory not found. Set OPEN_MP_INCLUDE_DIR explicitly." >&2
	exit 1
fi

if [[ ! -d "${RUN_DIR}/components" ]]; then
	echo "ERROR: components directory missing in ${RUN_DIR}" >&2
	exit 1
fi

mkdir -p "${RUN_DIR}/gamemodes" "${RUN_DIR}/scriptfiles"

cp "${MYSQL_COMPONENT_PATH}" "${RUN_DIR}/components/mysql.so"
cp "${LIBMARIADB_PATH}" "${RUN_DIR}/libmariadb.so.3"

CI_UNIT_TEST_PWN="${WORK_DIR}/unit_test_ci.pwn"
cp "${ROOT_DIR}/tests/unit_test.pwn" "${CI_UNIT_TEST_PWN}"
sed -E -i "s|^#define MYSQL_HOSTNAME \".*\"$|#define MYSQL_HOSTNAME \"${DB_HOST}\"|" "${CI_UNIT_TEST_PWN}"
sed -E -i "s|^#define MYSQL_USERNAME \".*\"$|#define MYSQL_USERNAME \"${DB_USER}\"|" "${CI_UNIT_TEST_PWN}"
sed -E -i "s|^#define MYSQL_PASSWORD \".*\"$|#define MYSQL_PASSWORD \"${DB_PASS}\"|" "${CI_UNIT_TEST_PWN}"
sed -E -i "s|^#define MYSQL_DATABASE \".*\"$|#define MYSQL_DATABASE \"${DB_NAME}\"|" "${CI_UNIT_TEST_PWN}"

echo "Compiling unit_test.pwn with ${PAWNCC_BIN}"
"${PAWNCC_BIN}" "${CI_UNIT_TEST_PWN}" -D"${ROOT_DIR}/tests" -d3 -Z \
	-i"${ROOT_DIR}/tests/include" \
	-i"${OPEN_MP_INCLUDE_DIR}" \
	-i"${BUILD_DIR}/src" \
	-o"${RUN_DIR}/gamemodes/unit_test.amx" > "${COMPILE_LOG_PATH}" 2>&1

cp "${ROOT_DIR}/tests/test_data/scriptfiles/test.sql" "${RUN_DIR}/scriptfiles/test.sql"
cp "${ROOT_DIR}/tests/test_data/mysql-invalid1.ini" "${RUN_DIR}/mysql-invalid1.ini"
cp "${ROOT_DIR}/tests/test_data/mysql-invalid2.ini" "${RUN_DIR}/mysql-invalid2.ini"
cp "${ROOT_DIR}/tests/test_data/mysql-invalid3.ini" "${RUN_DIR}/mysql-invalid3.ini"
cp "${ROOT_DIR}/tests/test_data/mysql-invalid4.ini" "${RUN_DIR}/mysql-invalid4.ini"
cp "${ROOT_DIR}/tests/test_data/mysql-invalid5.ini" "${RUN_DIR}/mysql-invalid5.ini"

cat > "${RUN_DIR}/mysql.ini" <<EOF
hostname = ${DB_HOST}
username = ${DB_USER}
password = ${DB_PASS}
database = ${DB_NAME}
multi_statements = true
EOF

cat > "${RUN_DIR}/mysql-invalid.ini" <<EOF
hostname = ${DB_HOST}
username = invalid-user
password = ${DB_PASS}
database = ${DB_NAME}
EOF

cat > "${RUN_DIR}/config.json" <<'EOF'
{
  "name": "mysql unit test",
  "announce": false,
  "enable_query": false,
  "max_players": 1,
  "network": {
    "bind": "127.0.0.1",
    "port": 7779
  },
  "logging": {
    "enable": true,
    "file": "log.txt"
  },
  "pawn": {
    "legacy_plugins": [],
    "main_scripts": [
      "unit_test 1"
    ],
    "side_scripts": []
  },
  "rcon": {
    "enable": true,
    "password": "test"
  }
}
EOF

echo "Running open.mp unit tests..."
(
	cd "${RUN_DIR}"
	timeout "${UNIT_TEST_TIMEOUT}" ./omp-server > "${LOG_PATH}" 2>&1 || true
)

if grep -q "All tests passed!" "${LOG_PATH}"; then
	echo "Unit tests passed."
	exit 0
fi

echo "Unit tests failed. Summary:" >&2
grep -nE "All tests passed|tests failed|ASSERT FAILED|executing test|passed!|failed\\.|component.mysql|Error|ERROR" "${LOG_PATH}" | tail -n 300 >&2 || true
echo "Full runtime log: ${LOG_PATH}" >&2
echo "Compile log: ${COMPILE_LOG_PATH}" >&2
exit 1
