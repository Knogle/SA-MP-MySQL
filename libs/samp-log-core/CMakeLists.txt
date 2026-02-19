cmake_minimum_required(VERSION 3.15)
cmake_policy(SET CMP0091 NEW)
project(samp-log-core VERSION 0.4)

if (NOT LOGCORE_VERSION) # allow version override
	set(LOGCORE_VERSION ${PROJECT_VERSION})
endif()
option(LOGCORE_STATIC_RUNTIME "Link GCC runtimes statically on UNIX." OFF)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/libs/cmake")

set(CMAKE_CXX_STANDARD 11) #required for fmt library

if (MSVC)
	add_link_options(/INCREMENTAL:NO /NODEFAULTLIB:MSVCRT)
	# link runtime statically
	set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
elseif(UNIX)
	# hide non-exported symbols
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden")
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden")
	set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS OFF)

	if(LOGCORE_STATIC_RUNTIME)
		# link runtime statically
		set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
		add_link_options(
			"-static-libgcc"
			"-static-libstdc++"
		)
	endif()
endif()

set(LOGCORE_LIBS_DIR "${PROJECT_SOURCE_DIR}/libs")

if(NOT TARGET fmt)
	add_subdirectory(libs/fmt)
	mark_as_advanced(FMT_TEST FMT_INSTALL FMT_PEDANTIC FMT_DOC FMT_USE_CPP11 FMT_WERROR)
endif()

if(NOT TARGET yaml-cpp)
	if(EXISTS "${CMAKE_SOURCE_DIR}/libs/yaml-cpp/CMakeLists.txt")
		set(YAML_CPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
		set(YAML_CPP_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
		set(YAML_CPP_INSTALL OFF CACHE BOOL "" FORCE)
		add_subdirectory("${CMAKE_SOURCE_DIR}/libs/yaml-cpp" "${CMAKE_BINARY_DIR}/yaml-cpp")
	else()
		find_package(yaml-cpp REQUIRED CONFIG)
	endif()
endif()

add_subdirectory(src)
