include(AMXConfig)

if(NOT WIN32 AND MYSQLCAPI_LIBRARY_STATIC)
	option(BUILD_STATIC "Build static library" OFF)
endif()

set(SAMP_SDK_ROOT "${PROJECT_SOURCE_DIR}/libs/sdk")
find_package(SAMPSDK REQUIRED)

set(MYSQL_PLUGIN_CONFIG_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/config_headers")

configure_file(
	"../a_mysql.inc.in"
	"a_mysql.inc"
	@ONLY
)

configure_file(
	"version.hpp.in"
	"${MYSQL_PLUGIN_CONFIG_INCLUDE_DIR}/version.hpp"
	@ONLY
)

add_library(mysql SHARED
	${SAMPSDK_DIR}/amxplugin.cpp
	${SAMPSDK_DIR}/amxplugin2.cpp
	${SAMPSDK_DIR}/amx/getch.c
	CCallback.cpp
	CCallback.hpp
	CConnection.cpp
	CConnection.hpp
	CDispatcher.cpp
	CDispatcher.hpp
	CError.hpp
	CHandle.cpp
	CHandle.hpp
	CLog.cpp
	CLog.hpp
	COptions.cpp
	COptions.hpp
	COrm.cpp
	COrm.hpp
	CQuery.cpp
	CQuery.hpp
	CResult.cpp
	CResult.hpp
	plugin_runtime.cpp
	plugin_runtime.hpp
	natives.cpp
	natives.hpp
	CSingleton.hpp
	main.cpp
	misc.hpp
	mysql.hpp
	amx_sdk.hpp
	types.hpp
)

set_target_properties(mysql PROPERTIES PREFIX "")

target_include_directories(mysql PRIVATE
	${SAMPSDK_INCLUDE_DIR}
	${MYSQL_PLUGIN_CONFIG_INCLUDE_DIR}
	${Boost_INCLUDE_DIR}
	${MYSQLCAPI_INCLUDE_DIR}
)

target_compile_features(mysql PUBLIC
	cxx_auto_type
	cxx_decltype
	cxx_defaulted_functions
	cxx_default_function_template_args
	cxx_delegating_constructors
	cxx_deleted_functions
	cxx_enum_forward_declarations
	cxx_explicit_conversions
	cxx_extended_friend_declarations
	cxx_lambdas
	cxx_inheriting_constructors
	cxx_noexcept
	cxx_nonstatic_member_init
	cxx_nullptr
	cxx_range_for
	cxx_reference_qualified_functions
	cxx_right_angle_brackets
	cxx_rvalue_references
	cxx_strong_enums
	cxx_variadic_templates
)

add_dependencies(mysql fmt)

if(MSVC)
	target_compile_definitions(mysql PRIVATE
		_CRT_SECURE_NO_WARNINGS
		NOMINMAX
		_ENABLE_ATOMIC_ALIGNMENT_FIX
	)
elseif(UNIX)
	target_compile_definitions(mysql PRIVATE LINUX)
endif()

target_link_libraries(mysql PRIVATE
	OMP-SDK
	fmt
)

if(UNIX)
	if(NOT APPLE)
		target_link_libraries(mysql PRIVATE rt)
	endif()

	set_target_properties(mysql PROPERTIES
		INSTALL_RPATH "$ORIGIN/..:$ORIGIN/")
endif()

if(BUILD_STATIC)
	target_link_libraries(mysql PRIVATE "${MYSQLCAPI_LIBRARY_STATIC}")
else()
	target_link_libraries(mysql PRIVATE "${MYSQLCAPI_LIBRARY}")
endif()

install(TARGETS mysql DESTINATION "components/")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/a_mysql.inc" DESTINATION "pawno/include/")
install(FILES "${PROJECT_SOURCE_DIR}/LICENSE" DESTINATION "./")
if(WIN32 AND MYSQLCAPI_LIBRARY_SHARED)
	install(FILES "${MYSQLCAPI_LIBRARY_SHARED}" DESTINATION "./")
elseif(UNIX AND NOT BUILD_STATIC)
	set(_MYSQL_RUNTIME_LIB_CANDIDATES
		"${MYSQLCAPI_LIBRARY_SHARED}"
		"${MYSQLCAPI_LIBRARY}"
		"${PROJECT_SOURCE_DIR}/libs/mariadb-connector-c/lib32/libmariadb.so.3"
	)

	set(_MYSQL_RUNTIME_LIB_TO_INSTALL "")
	foreach(_candidate IN LISTS _MYSQL_RUNTIME_LIB_CANDIDATES)
		if(_candidate AND EXISTS "${_candidate}")
			get_filename_component(_candidate_real "${_candidate}" REALPATH)
			if(EXISTS "${_candidate_real}")
				set(_MYSQL_RUNTIME_LIB_TO_INSTALL "${_candidate_real}")
				break()
			endif()
		endif()
	endforeach()

	if(_MYSQL_RUNTIME_LIB_TO_INSTALL)
		install(FILES "${_MYSQL_RUNTIME_LIB_TO_INSTALL}" DESTINATION "./")
	endif()
endif()

set(CPACK_PACKAGE_VERSION ${MYSQL_PLUGIN_VERSION})
if(WIN32)
	set(CPACK_GENERATOR ZIP)
else()
	set(CPACK_GENERATOR TGZ)
endif()

include(CPack)
