# If the MUSICA library is not installed, it will fetch
# the MUSICA repository to build the library
if(NOT $ENV{USE_INSTALLED_MUSICA_LIB})  # Set by docker
  include(FetchContent)

  FetchContent_Declare(musica
    GIT_REPOSITORY https://github.com/NCAR/musica.git
    GIT_TAG        $ENV{MUSICA_GIT_TAG}  # Set by docker
  )

  set(MUSICA_BUILD_C_CXX_INTERFACE ON)
  set(MUSICA_BUILD_FORTRAN_INTERFACE ON)
  set(MUSICA_ENABLE_TESTS OFF)
  set(MUSICA_ENABLE_INSTALL OFF)

  FetchContent_MakeAvailable(musica)

else()
  if (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ffree-line-length-none")
  endif()

  link_directories("/usr/local/lib")
endif()

find_package(Python REQUIRED)

# Copy configuration files to the build directory
add_custom_target(copy_musica_test_data ALL ${CMAKE_COMMAND} -E copy_directory
  ${CMAKE_CURRENT_SOURCE_DIR}/configuration
  ${CMAKE_BINARY_DIR}/test/musica/configuration
)

# Test metadata against the source code
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/metadata_test)
add_custom_target(
  copy_metadata_test_files ALL ${CMAKE_COMMAND} -E copy
  ${CMAKE_CURRENT_SOURCE_DIR}/../../schemes/musica/musica_ccpp.meta
  ${CMAKE_CURRENT_SOURCE_DIR}/../../schemes/musica/musica_ccpp.F90
  ${CMAKE_BINARY_DIR}/metadata_test
)

add_test(
  NAME test_metadata_against_source_code
  COMMAND ${Python_EXECUTABLE} ${CMAKE_BINARY_DIR}/../$ENV{CCPP_FORTRAN_TOOLS_PATH}/offline_check_fortran_vs_metadata.py
  --directory ${CMAKE_BINARY_DIR}/metadata_test
)

# Test musica scheme metadata against the CCPP standard names
add_test(
  NAME test_musica_metadata_against_ccpp_standard_names
  COMMAND ${Python_EXECUTABLE} ${CMAKE_BINARY_DIR}/../$ENV{CCPP_STD_NAMES_PATH}/tools/ccpp_meta_stdname_check.py
  --metafile-loc ${CMAKE_BINARY_DIR}/metadata_test/musica_ccpp.meta
  --stdname-dict ${CMAKE_BINARY_DIR}/../$ENV{CCPP_STD_NAMES_PATH}/standard_names.xml
)

# MUSICA CCPP API test
add_executable(test_musica_api test_musica_api.F90)

file(GLOB MUSICA_CCPP_SOURCES
  ${MUSICA_SRC_PATH}/*.F90
  ${MUSICA_SRC_PATH}/micm/*.F90
  ${MUSICA_SRC_PATH}/tuvx/*.F90
  ${MUSICA_SRC_PATH}/util/*.F90
  ${MUSICA_SRC_PATH}/aerosol/*.F90
  ${MUSICA_SRC_PATH}/aerosol_stub/*.F90
)

target_sources(test_musica_api
  PUBLIC
    ${MUSICA_CCPP_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/musica_ccpp_namelist.F90
    ${CMAKE_CURRENT_SOURCE_DIR}/musica_test_data.F90
    ${TO_BE_CCPPIZED_SRC_PATH}/ccpp_tuvx_utils.F90
    ${TO_BE_CCPPIZED_SRC_PATH}/ccpp_const_utils.F90
    ${CCPP_SRC_PATH}/ccpp_constituent_prop_mod.F90
    ${CCPP_SRC_PATH}/ccpp_hash_table.F90
    ${CCPP_SRC_PATH}/ccpp_hashable.F90
    ${CCPP_SRC_PATH}/ccpp_types.F90
    ${CCPP_TEST_SRC_PATH}/ccpp_kinds.F90
)

target_link_libraries(test_musica_api
  PRIVATE
    musica-fortran musica mechanism_configuration yaml-cpp stdc++ netcdff
)

add_test(
  NAME test_musica_api
  COMMAND $<TARGET_FILE:test_musica_api>
  WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
)

add_memory_check_test(test_musica_api $<TARGET_FILE:test_musica_api> "" ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

# MUSICA species test
add_executable(test_musica_species test_musica_species.F90 musica_ccpp_namelist.F90)

target_sources(test_musica_species
  PUBLIC
    ${MUSICA_CCPP_SOURCES}
    ${TO_BE_CCPPIZED_SRC_PATH}/ccpp_const_utils.F90
    ${TO_BE_CCPPIZED_SRC_PATH}/ccpp_tuvx_utils.F90
    ${CCPP_SRC_PATH}/ccpp_constituent_prop_mod.F90
    ${CCPP_SRC_PATH}/ccpp_hash_table.F90
    ${CCPP_SRC_PATH}/ccpp_hashable.F90
    ${CCPP_TEST_SRC_PATH}/ccpp_kinds.F90
)

target_link_libraries(test_musica_species
  PRIVATE
    musica-fortran musica mechanism_configuration yaml-cpp stdc++ netcdff
)

add_test(
  NAME test_musica_species
  COMMAND $<TARGET_FILE:test_musica_species>
  WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
)

add_memory_check_test(test_musica_species $<TARGET_FILE:test_musica_species> "" ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

add_subdirectory(aerosol)
add_subdirectory(aerosol_stub)
add_subdirectory(micm)
add_subdirectory(tuvx)
add_subdirectory(util)
