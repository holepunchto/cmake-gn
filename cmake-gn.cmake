include_guard()

set(GN_DIR "" CACHE PATH "Path to the GN root directory")

set(GN_OUT_DIR "" CACHE PATH "Path to the GN output directory")

function(find_gn result)
  find_program(gn NAMES gn.bat gn REQUIRED)

  set(${result} ${gn})

  return(PROPAGATE ${result})
endfunction()

function(add_gn_target name target)
  if(NOT target MATCHES "^//")
    set(target "//${target}")
  endif()

  _gn_describe("${target}" json)

  string(JSON type GET "${json}" "${target}" "type")

  if(type STREQUAL "static_library")
    add_library(${name} STATIC IMPORTED)

    string(JSON output GET "${json}" "${target}" "outputs" 0)

    _gn_path("${output}" output)

    set_target_properties(
      ${name}
      PROPERTIES
      IMPORTED_LOCATION "${output}"
    )
  else()
    message(FATAL_ERROR "Unknown target type \"${type}\" for GN target \"${target}\"")
  endif()

  # Only the configs that GN applies to the dependents of the target are part
  # of its interface. The flags it is compiled with are not.
  foreach(key IN ITEMS public_configs all_dependent_configs)
    _gn_list("${json}" configs "${target}" ${key})

    foreach(config IN LISTS configs)
      _gn_describe("${config}" config_json)

      _gn_add_config(${name} "${config_json}" "${config}")
    endforeach()
  endforeach()
endfunction()

function(add_gn_package name)
  cmake_parse_arguments(PARSE_ARGV 1 ARGV "INSTALL" "" "")

  _gn_out_dir(out_dir)

  set(prefix "${out_dir}/package/${name}")

  if(NOT EXISTS "${prefix}/lib/cmake/${name}/${name}-config.cmake")
    message(FATAL_ERROR "Package \"${name}\" not found in \"${prefix}\", build the GN target that writes it first")
  endif()

  find_package(${name} CONFIG REQUIRED PATHS "${prefix}" NO_DEFAULT_PATH)

  if(ARGV_INSTALL)
    install(
      DIRECTORY "${prefix}/"
      DESTINATION .
      USE_SOURCE_PERMISSIONS
    )
  endif()

  return(PROPAGATE ${name}_FOUND ${name}_VERSION)
endfunction()

function(_gn_describe label result)
  find_gn(gn)

  execute_process(
    COMMAND ${gn} desc ${GN_OUT_DIR} ${label} --format=json
    WORKING_DIRECTORY ${GN_DIR}
    OUTPUT_VARIABLE json
    COMMAND_ERROR_IS_FATAL ANY
  )

  set(${result} "${json}")

  return(PROPAGATE ${result})
endfunction()

function(_gn_out_dir result)
  cmake_path(ABSOLUTE_PATH GN_OUT_DIR BASE_DIRECTORY "${GN_DIR}" NORMALIZE OUTPUT_VARIABLE dir)

  string(REGEX REPLACE "(.)/$" "\\1" dir "${dir}")

  set(${result} "${dir}")

  return(PROPAGATE ${result})
endfunction()

# Converts a GN path, which is either relative to the GN root as in `//foo` or
# system absolute as in `/foo` or `/C:/foo`, to a native path.
function(_gn_path path result)
  if(path MATCHES "^//(.*)$")
    set(path "${GN_DIR}/${CMAKE_MATCH_1}")
  elseif(path MATCHES "^/([A-Za-z]:.*)$")
    set(path "${CMAKE_MATCH_1}")
  endif()

  cmake_path(NORMAL_PATH path)

  string(REGEX REPLACE "(.)/$" "\\1" path "${path}")

  set(${result} "${path}")

  return(PROPAGATE ${result})
endfunction()

# Reads the list at the given keys of the JSON, or an empty list if it's absent.
function(_gn_list json result)
  set(${result})

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" ${ARGN})

  if(error MATCHES "NOTFOUND" AND len GREATER 0)
    math(EXPR last "${len} - 1")

    foreach(i RANGE ${last})
      string(JSON item GET "${json}" ${ARGN} ${i})

      list(APPEND ${result} "${item}")
    endforeach()
  endif()

  return(PROPAGATE ${result})
endfunction()

function(_gn_add_config name json config)
  _gn_list("${json}" defines "${config}" defines)

  target_compile_definitions(${name} INTERFACE ${defines})

  _gn_list("${json}" dirs "${config}" include_dirs)

  foreach(dir IN LISTS dirs)
    _gn_path("${dir}" dir)

    # Generated directories that the build hasn't written don't exist, and
    # CMake rejects imported targets that include them.
    if(IS_DIRECTORY "${dir}")
      target_include_directories(${name} INTERFACE "${dir}")
    endif()
  endforeach()

  _gn_list("${json}" flags "${config}" cflags)

  target_compile_options(${name} INTERFACE ${flags})

  foreach(pair IN ITEMS c:C cc:CXX objc:OBJC objcc:OBJCXX)
    string(REPLACE ":" ";" pair "${pair}")

    list(GET pair 0 suffix)
    list(GET pair 1 language)

    _gn_list("${json}" flags "${config}" cflags_${suffix})

    foreach(flag IN LISTS flags)
      target_compile_options(${name} INTERFACE "$<$<COMPILE_LANGUAGE:${language}>:${flag}>")
    endforeach()
  endforeach()

  _gn_list("${json}" flags "${config}" ldflags)

  target_link_options(${name} INTERFACE ${flags})

  _gn_list("${json}" dirs "${config}" lib_dirs)

  foreach(dir IN LISTS dirs)
    _gn_path("${dir}" dir)

    target_link_directories(${name} INTERFACE "${dir}")
  endforeach()

  _gn_list("${json}" libs "${config}" libs)

  foreach(lib IN LISTS libs)
    if(lib MATCHES "^/")
      _gn_path("${lib}" lib)
    endif()

    target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:DEFAULT,${lib}>")
  endforeach()

  _gn_list("${json}" weak "${config}" weak_frameworks)

  foreach(framework IN LISTS weak)
    target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:WEAK_FRAMEWORK,${framework}>")
  endforeach()

  _gn_list("${json}" frameworks "${config}" frameworks)

  foreach(framework IN LISTS frameworks)
    if(NOT framework IN_LIST weak)
      target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:FRAMEWORK,${framework}>")
    endif()
  endforeach()
endfunction()
