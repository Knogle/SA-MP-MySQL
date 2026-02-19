cmake_minimum_required(VERSION 3.19)
project(mysql)

set(MYSQL_PLUGIN_VERSION "R41-4")

option (BUILD_TESTS "Build tests" OFF)
option (FORCE_32_BIT "Force 32-bit compilation on UNIX" ON)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/libs/cmake")

if(UNIX)
	#hide non-exported symbols
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden")
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden")

	#force 32bit compilation when requested
	if(FORCE_32_BIT)
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
		set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS OFF)
	endif()
endif()

set(_BUNDLED_MARIADB_ROOT "${PROJECT_SOURCE_DIR}/libs/mariadb-connector-c")
if(EXISTS "${_BUNDLED_MARIADB_ROOT}/include/mysql.h")
	set(MYSQLCAPI_ROOT_DIR "${_BUNDLED_MARIADB_ROOT}" CACHE PATH "Bundled MariaDB Connector/C root.")
	if(NOT MYSQLCAPI_INCLUDE_DIR)
		set(MYSQLCAPI_INCLUDE_DIR "${_BUNDLED_MARIADB_ROOT}/include" CACHE PATH "Bundled MariaDB Connector/C include path.")
	endif()
	if(FORCE_32_BIT)
		if(NOT MYSQLCAPI_LIBRARY AND EXISTS "${_BUNDLED_MARIADB_ROOT}/lib32/libmariadb.so.3")
			set(MYSQLCAPI_LIBRARY "${_BUNDLED_MARIADB_ROOT}/lib32/libmariadb.so.3" CACHE FILEPATH "Bundled MariaDB Connector/C library path.")
		endif()
	elseif(NOT MYSQLCAPI_LIBRARY AND EXISTS "/usr/lib64/libmariadb.so.3")
		set(MYSQLCAPI_LIBRARY "/usr/lib64/libmariadb.so.3" CACHE FILEPATH "System MariaDB Connector/C library path.")
	endif()
endif()


find_package(MySQLCAPI REQUIRED)

set(Boost_USE_STATIC_LIBS ON)
find_package(Boost 1.57 QUIET)
if(NOT Boost_FOUND)
	set(_BUNDLED_BOOST_ROOT "${PROJECT_SOURCE_DIR}/libs/boost")
	if(EXISTS "${_BUNDLED_BOOST_ROOT}/boost/version.hpp")
		set(Boost_FOUND ON)
		set(Boost_INCLUDE_DIR "${_BUNDLED_BOOST_ROOT}")
		message(STATUS "Using bundled Boost headers from ${_BUNDLED_BOOST_ROOT}")
	else()
		set(BOOST_ROOT "${BOOST_ROOT}" CACHE PATH "Set the Boost root folder.")
		mark_as_advanced(CLEAR BOOST_ROOT)
		message(FATAL_ERROR "Could NOT find Boost; specify additional path.")
	endif()
endif()
mark_as_advanced(BOOST_ROOT Boost_DIR)

if(NOT TARGET fmt)
	add_subdirectory(libs/fmt)
endif()
mark_as_advanced(FMT_DOC FMT_INSTALL FMT_PEDANTIC FMT_TEST FMT_USE_CPP11)

if(EXISTS "${PROJECT_SOURCE_DIR}/libs/omp-sdk/CMakeLists.txt")
	add_subdirectory(libs/omp-sdk)
else()
	message(FATAL_ERROR "open.mp SDK submodule not found. Run: git submodule update --init --recursive")
endif()

add_subdirectory(src)
