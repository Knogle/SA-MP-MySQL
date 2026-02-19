# MySQL Component for open.mp

[![Build and Release](https://github.com/Knogle/SA-MP-MySQL/actions/workflows/ci.yml/badge.svg)](https://github.com/Knogle/SA-MP-MySQL/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/Knogle/SA-MP-MySQL?display_name=tag)](https://github.com/Knogle/SA-MP-MySQL/releases)
[![Total Downloads](https://img.shields.io/github/downloads/Knogle/SA-MP-MySQL/total.svg)](https://github.com/Knogle/SA-MP-MySQL/releases)
[![Latest Release Downloads](https://img.shields.io/github/downloads/Knogle/SA-MP-MySQL/latest/total.svg)](https://github.com/Knogle/SA-MP-MySQL/releases)

The MySQL component for open.mp servers.

Current release: **R42**

Current maintainer: **[Knogle](https://github.com/Knogle)**

## R42 Highlights

- Full GitHub Actions pipeline for **Linux and Windows** builds.
- CI checks on **every push and pull request**.
- Automated package creation and upload on **GitHub Release publish**.
- Build and compatibility refresh for modern open.mp environments.
- Removed old `samp-log-core`/logcore dependency; logging now uses open.mp core logging (`ICore::logLn`) directly.

## Installation

1. Download the latest release archive from the [Releases page](https://github.com/Knogle/SA-MP-MySQL/releases).
2. Extract it into your open.mp server root.
3. Copy the full release `components/` contents into your server's `components` folder (Linux: `mysql.so` + `libmariadb.so.3`, Windows: `mysql.dll` + `libmariadb.dll`).
4. No `config.json` changes are required.

## Logging Configuration

The component supports open.mp config-based logging toggles:

- `logging.mysql`
- `logging.mysql_debug`
- `logging.mysql_info`
- `logging.mysql_warning`
- `logging.mysql_error`

## Build from Source

### Repository setup

```bash
git clone https://github.com/Knogle/SA-MP-MySQL.git
cd SA-MP-MySQL
git submodule update --init --recursive
```

### Linux

Default build is 32-bit (`FORCE_32_BIT=ON`).

```bash
cmake -S . -B build -DFORCE_32_BIT=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build build --parallel
```

Output:

- `build/src/mysql.so`

### Windows (Visual Studio 2022, Win32)

Install MariaDB Connector/C x86 (for example via vcpkg), then configure and build:

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A Win32 -DMYSQLCAPI_ROOT_DIR="<path-to-mariadb-x86-root>"
cmake --build build --config Release --parallel
```

Output:

- `build/src/Release/mysql.dll`

## CI/CD

Workflow file: `.github/workflows/ci.yml`

Triggers:

- `push`
- `pull_request`
- `release` (`published`)
- `workflow_dispatch`

Release behavior:

- Builds Linux and Windows artifacts.
- Packages both builds via CPack.
- Uploads packages automatically to the matching GitHub Release.

## Compatibility

- Runtime target: open.mp servers
- SDK: open.mp SDK (submodule)
- Bundled dependencies in repo:
  - Boost headers
  - MariaDB Connector/C (Linux)

## Credits

This project builds on the long work of the original SA-MP MySQL plugin contributors and maintainers.
