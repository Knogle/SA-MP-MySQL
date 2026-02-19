# Look for MySQL C API
# Once done, this will define
#
#  MYSQLCAPI_FOUND - system has MySQL C API
#  MYSQLCAPI_INCLUDE_DIR - MySQL C API include directories
#  MYSQLCAPI_LIBRARY - MySQL C library
#  MYSQLCAPI_LIBRARY_SHARED - MySQL C shared library (.dll file on Windows; same as MYSQLCAPI_LIBRARY on Linux)
#  MYSQLCAPI_LIBRARY_STATIC - MySQL C static library (Linux only)
#
# The user may wish to set, in the CMake GUI or otherwise, this variable:
#  MYSQLCAPI_ROOT_DIR - path to start searching for the module

set(MYSQLCAPI_ROOT_DIR
	"${MYSQLCAPI_ROOT_DIR}"
	CACHE
	PATH
	"Where to start looking for this component."
)

if(WIN32)
    find_path(
		MYSQLCAPI_INCLUDE_DIR
		NAMES
		"mysql.h"
		"mariadb_version.h"
		"mysql_version.h"
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		PATH_SUFFIXES
		include
		include/mysql
		include/mariadb
	)

    find_library(
		MYSQLCAPI_LIBRARY
		NAMES
		"libmariadb.lib"
		"libmysql.lib"
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		PATH_SUFFIXES
		lib
	)

	find_file(
		MYSQLCAPI_LIBRARY_SHARED
		NAMES
		"libmariadb.dll"
		"libmysql.dll"
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		PATH_SUFFIXES
		bin
		lib
	)
else()
    find_path(
		MYSQLCAPI_INCLUDE_DIR
		NAMES
		"mysql_version.h"
		"mariadb_version.h"
		"mysql.h"
		PATHS
		"/usr/include"
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		"${CMAKE_SOURCE_DIR}/libs/mariadb-connector-c"
		PATH_SUFFIXES
		include
		mysql
		mariadb
	)

    find_library(
		MYSQLCAPI_LIBRARY
		NAMES
		mysqlclient_r
		mysqlclient
		mariadb
		libmariadb
		libmariadb.so.3
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		PATH_SUFFIXES
		lib32
		lib
		mysql
		mariadb
		i386-linux-gnu
		x86_64-linux-gnu
	)
	if(NOT MYSQLCAPI_LIBRARY)
		find_file(
			MYSQLCAPI_LIBRARY
			NAMES
			"libmariadb.so.3"
			"libmysqlclient.so"
			HINTS
			${MYSQLCAPI_ROOT_DIR}
			PATH_SUFFIXES
			lib32
			lib
			mysql
			mariadb
			i386-linux-gnu
			x86_64-linux-gnu
		)
	endif()
	set(MYSQLCAPI_LIBRARY_SHARED ${MYSQLCAPI_LIBRARY})

    find_library(
		MYSQLCAPI_LIBRARY_STATIC
		NAMES
		"libmysqlclient.a"
		"libmariadb.a"
		HINTS
		${MYSQLCAPI_ROOT_DIR}
		PATH_SUFFIXES
		lib32
		lib
		mysql
		mariadb
		i386-linux-gnu
		x86_64-linux-gnu
	)
endif()

mark_as_advanced(
	MYSQLCAPI_INCLUDE_DIR
	MYSQLCAPI_LIBRARY
	MYSQLCAPI_LIBRARY_SHARED
	MYSQLCAPI_LIBRARY_STATIC
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
	MySQLCAPI
	REQUIRED_VARS
		MYSQLCAPI_INCLUDE_DIR
		MYSQLCAPI_LIBRARY
)

if(MYSQLCAPI_FOUND)
    mark_as_advanced(MYSQLCAPI_ROOT_DIR)
endif()
