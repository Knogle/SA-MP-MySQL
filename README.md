# MySQL Component for open.mp

[![Build and Release](https://github.com/Knogle/SA-MP-MySQL/actions/workflows/ci.yml/badge.svg)](https://github.com/Knogle/SA-MP-MySQL/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/Knogle/SA-MP-MySQL?display_name=tag)](https://github.com/Knogle/SA-MP-MySQL/releases)
[![Total Downloads](https://img.shields.io/github/downloads/Knogle/SA-MP-MySQL/total.svg)](https://github.com/Knogle/SA-MP-MySQL/releases)
[![Latest Release Downloads](https://img.shields.io/github/downloads/Knogle/SA-MP-MySQL/latest/total.svg)](https://github.com/Knogle/SA-MP-MySQL/releases)

The MySQL component for open.mp servers.

Current release: **R42**

Current maintainer: **[Knogle](https://github.com/Knogle)**

## R42 Highlights

- CI pipelines for **GitHub Actions and GitLab CI** (Linux + optional Windows).
- CI checks on **every push and pull request**.
- Automated package creation for **GitHub and GitLab releases**.
- Build and compatibility refresh for modern open.mp environments.
- Removed old `samp-log-core`/logcore dependency; logging now uses open.mp core logging (`ICore::logLn`) directly.

## Installation

1. Download the latest release archive from the [Releases page](https://github.com/Knogle/SA-MP-MySQL/releases).
2. Extract it into your open.mp server root.
3. Copy the full release contents while preserving structure:
   - `components/mysql.so` (Linux) or `components/mysql.dll` (Windows)
   - `libmariadb.so.3` (Linux) or `libmariadb.dll` (Windows) in the server root
4. No `config.json` changes are required.

## Logging Configuration

The component supports open.mp config-based logging toggles:

- `logging.mysql`
- `logging.mysql_debug`
- `logging.mysql_info`
- `logging.mysql_warning`
- `logging.mysql_error`

## Linux Runtime Dependency (`libmariadb.so.3`)

`libmariadb.so.3` must be available for the Linux component at runtime (32-bit).

If you use the official release archive, keep the bundled `libmariadb.so.3` in the server root
(`components/..`) and copy `mysql.so` to `components/`.

If you build/deploy manually without the bundled source build, install the 32-bit MariaDB connector library via your distro:

- Fedora:
  - `sudo dnf install mariadb-connector-c.i686`
- Ubuntu/Debian:
  - `sudo dpkg --add-architecture i386`
  - `sudo apt update`
  - `sudo apt install libmariadb3:i386`
- CentOS/RHEL/Alma/Rocky:
  - `sudo dnf install mariadb-connector-c.i686`

If you build this repository with the bundled Connector/C submodule (`BUILD_BUNDLED_MARIADB_CONNECTOR=ON`, default on Linux),
`libmariadb.so.3` is built from source and packaged automatically.

## Build from Source

### Repository setup

```bash
git clone https://github.com/Knogle/SA-MP-MySQL.git
cd SA-MP-MySQL
git submodule update --init --recursive
```

### Linux

Default build is 32-bit (`FORCE_32_BIT=ON`).

For `FORCE_32_BIT=ON`, ensure 32-bit OpenSSL development files are installed:

- Ubuntu/Debian:
  - `sudo dpkg --add-architecture i386`
  - `sudo apt update`
  - `sudo apt install libssl-dev:i386`
- Fedora:
  - `sudo dnf install openssl-devel.i686`
- CentOS/RHEL/Alma/Rocky:
  - `sudo dnf install openssl-devel.i686`

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
GitLab pipeline file: `.gitlab-ci.yml`

Triggers:

- `push`
- `pull_request` (GitHub) / Merge Request pipeline (GitLab)
- `release` (`published`, GitHub) / Git tag pipeline (GitLab)
- `workflow_dispatch` (GitHub) / Run pipeline (`web`, GitLab)

Release behavior:

- Builds Linux and (optionally) Windows artifacts.
- Packages tagged builds via CPack.
- Publishes release entries automatically with package asset links.

### GitLab Windows runner setup

Set the CI/CD variable `WINDOWS_RUNNER_TAG` to the tag of your Windows runner.
If this variable is empty, GitLab CI builds/releases Linux only.

## Compatibility

- Runtime target: open.mp servers
- SDK: open.mp SDK (submodule)
- Bundled dependencies in repo:
  - Boost headers
  - MariaDB Connector/C (Linux)

## Credits

This project builds on the long work of the original SA-MP MySQL plugin contributors and maintainers.
