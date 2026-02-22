#!/usr/bin/env bash
set -euo pipefail

PLUGIN_PATH="${1:-build/src/mysql.so}"
PLUGIN_DIR="$(dirname "${PLUGIN_PATH}")"
BUILD_DIR="$(cd "${PLUGIN_DIR}/.." && pwd)"

if [[ ! -f "${PLUGIN_PATH}" ]]; then
	echo "ERROR: plugin not found: ${PLUGIN_PATH}" >&2
	exit 1
fi

echo "Checking plugin: ${PLUGIN_PATH}"

if ! readelf -d "${PLUGIN_PATH}" | grep -Fq "Shared library: [libmariadb.so.3]"; then
	echo "ERROR: ${PLUGIN_PATH} is missing NEEDED entry for libmariadb.so.3" >&2
	readelf -d "${PLUGIN_PATH}" | sed -n '1,120p'
	exit 1
fi

LINK_TXT="${PLUGIN_DIR}/CMakeFiles/mysql.dir/link.txt"
MARIADB_PATH=""

if [[ -f "${LINK_TXT}" ]]; then
	LINK_CANDIDATE="$(tr ' ' '\n' < "${LINK_TXT}" | grep -E 'libmariadb\.so(\.[0-9]+)*$' | tail -n 1 || true)"
	if [[ -n "${LINK_CANDIDATE}" ]]; then
		if [[ "${LINK_CANDIDATE}" = /* ]]; then
			if [[ -f "${LINK_CANDIDATE}" ]]; then
				MARIADB_PATH="${LINK_CANDIDATE}"
			fi
		else
			LINK_BASE_1="$(dirname "${LINK_TXT}")"
			LINK_BASE_2="$(dirname "${PLUGIN_PATH}")"
			for base in "${LINK_BASE_1}" "${LINK_BASE_2}"; do
				CANDIDATE_PATH="$(realpath -m "${base}/${LINK_CANDIDATE}")"
				if [[ -f "${CANDIDATE_PATH}" ]]; then
					MARIADB_PATH="${CANDIDATE_PATH}"
					break
				fi
			done
		fi
	fi
fi

if [[ -z "${MARIADB_PATH}" || ! -f "${MARIADB_PATH}" ]]; then
	RUNPATH_DIRS="$(
		readelf -d "${PLUGIN_PATH}" \
		| awk -F'[][]' '/(RUNPATH|RPATH)/ { print $2 }' \
		| head -n 1 || true
	)"
	if [[ -n "${RUNPATH_DIRS}" ]]; then
		OLD_IFS="${IFS}"
		IFS=':'
		for dir in ${RUNPATH_DIRS}; do
			if [[ -f "${dir}/libmariadb.so.3" ]]; then
				MARIADB_PATH="${dir}/libmariadb.so.3"
				break
			fi
		done
		IFS="${OLD_IFS}"
	fi
fi

if [[ -z "${MARIADB_PATH}" || ! -f "${MARIADB_PATH}" ]]; then
	MARIADB_PATH="$(find "${BUILD_DIR}" libs/mariadb-connector-c -type f -name 'libmariadb.so.3' 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${MARIADB_PATH}" || ! -f "${MARIADB_PATH}" ]]; then
	echo "ERROR: could not locate linked libmariadb.so.3 in build output" >&2
	exit 1
fi

echo "Checking linked MariaDB library: ${MARIADB_PATH}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

nm -D "${PLUGIN_PATH}" \
	| awk '$NF ~ /^mysql_/ { print $NF }' \
	| sed 's/@.*//' \
	| LC_ALL=C sort -u > "${TMP_DIR}/mysql_imports.txt"

nm -D --defined-only "${MARIADB_PATH}" \
	| awk '$NF ~ /^mysql_/ { print $NF }' \
	| sed 's/@.*//' \
	| LC_ALL=C sort -u > "${TMP_DIR}/mysql_exports.txt"

if [[ ! -s "${TMP_DIR}/mysql_imports.txt" ]]; then
	echo "ERROR: no imported mysql_* symbols found in ${PLUGIN_PATH}" >&2
	exit 1
fi

LC_ALL=C comm -12 "${TMP_DIR}/mysql_imports.txt" "${TMP_DIR}/mysql_exports.txt" > "${TMP_DIR}/mysql_exported_needed.txt"
LC_ALL=C comm -23 "${TMP_DIR}/mysql_imports.txt" "${TMP_DIR}/mysql_exports.txt" > "${TMP_DIR}/mysql_missing.txt"

IMPORT_COUNT="$(wc -l < "${TMP_DIR}/mysql_imports.txt")"
EXPORTED_COUNT="$(wc -l < "${TMP_DIR}/mysql_exported_needed.txt")"
MISSING_COUNT="$(wc -l < "${TMP_DIR}/mysql_missing.txt")"

echo "Plugin expects mysql_* symbols (${IMPORT_COUNT}):"
sed 's/^/  - /' "${TMP_DIR}/mysql_imports.txt"
echo
echo "libmariadb exports for expected symbols (${EXPORTED_COUNT}):"
if [[ "${EXPORTED_COUNT}" -gt 0 ]]; then
	sed 's/^/  - /' "${TMP_DIR}/mysql_exported_needed.txt"
else
	echo "  (none)"
fi
echo
echo "Per-symbol resolution:"
awk '
	NR == FNR { exported[$0] = 1; next }
	{
		if (exported[$0]) print "  OK      " $0;
		else print "  MISSING " $0;
	}
' "${TMP_DIR}/mysql_exports.txt" "${TMP_DIR}/mysql_imports.txt"

if [[ "${MISSING_COUNT}" -ne 0 ]]; then
	echo "ERROR: linked libmariadb is missing exported mysql_* symbols required by plugin:" >&2
	sed -n '1,200p' "${TMP_DIR}/mysql_missing.txt" >&2
	exit 1
fi

echo "OK: mysql.so imports resolve against exported symbols in libmariadb.so.3"
