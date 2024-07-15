set(GN_DIR "" CACHE PATH "Path to the GN root directory")

set(GN_OUT_DIR "" CACHE PATH "Path to the GN output directory")

function(find_gn result)
  find_program(gn NAMES gn.bat gn REQUIRED)

  set(${result} ${gn})

  return(PROPAGATE ${result})
endfunction()

function(add_gn_target name target)
  find_gn(gn)

  execute_process(
    COMMAND ${gn} desc ${GN_OUT_DIR} ${target} --format=json
    WORKING_DIRECTORY ${GN_DIR}
    OUTPUT_VARIABLE json
    COMMAND_ERROR_IS_FATAL ANY
  )

  string(JSON type GET "${json}" "//${target}" "type")

  if(type MATCHES "static_library")
    add_gn_static_library(${name} ${target} "${json}")
  else()
    message(FATAL_ERROR "Unknown target type \"${type}\" for GN target \"${target}\"")
  endif()
endfunction()

function(add_gn_static_library name target json)
  add_library(${name} STATIC IMPORTED)

  string(JSON output ERROR_VARIABLE error GET "${json}" "//${target}" "outputs" 0)

  if(error MATCHES "NOTFOUND")
    set(output "${GN_DIR}${output}")

    cmake_path(NORMAL_PATH output)

    set_target_properties(
      ${name}
      PROPERTIES
      IMPORTED_LOCATION ${output}
    )
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "include_dirs")

  if(error MATCHES "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON dir GET "${json}" "//${target}" "include_dirs" ${i})

        set(dir "${GN_DIR}${dir}")

        cmake_path(NORMAL_PATH dir)

        if(IS_DIRECTORY "${dir}")
          target_include_directories(${name} INTERFACE "${dir}")
        endif()
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "defines")

  if(error MATCHES "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON definition GET "${json}" "//${target}" "defines" ${i})

        target_compile_definitions(${name} INTERFACE ${definition})
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "libs")

  if(error MATCHES "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON lib GET "${json}" "//${target}" "libs" ${i})

        cmake_path(IS_ABSOLUTE lib is_absolute)

        if(is_absolute)
          set(lib "${GN_DIR}${lib}")

          cmake_path(NORMAL_PATH lib)
        endif()

        target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:DEFAULT,${lib}>")
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "weak_frameworks")

  if(error MATCHES "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON framework GET "${json}" "//${target}" "weak_frameworks" ${i})

        list(APPEND frameworks ${framework})

        target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:WEAK_FRAMEWORK,${framework}>")
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "frameworks")

  if(error MATCHES "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON framework GET "${json}" "//${target}" "frameworks" ${i})

        if(NOT framework IN_LIST frameworks)
          target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:FRAMEWORK,${framework}>")
        endif()
      endif()
    endforeach()
  endif()
endfunction()
