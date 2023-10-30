set(GN_DIR "" CACHE PATH "Path to the GN root directory")

set(GN_OUT_DIR "" CACHE PATH "Path to the GN output directory")

function(add_gn_library name target type)
  add_library(${name} ${type} IMPORTED)

  find_gn(gn)

  execute_process(
    COMMAND ${gn} desc ${GN_OUT_DIR} ${target} --format=json
    WORKING_DIRECTORY ${GN_DIR}
    OUTPUT_VARIABLE json
    COMMAND_ERROR_IS_FATAL ANY
  )

  string(JSON output GET "${json}" "//${target}" "outputs" 0)

  set(location "${GN_DIR}${output}")

  cmake_path(NORMAL_PATH location)

  set_target_properties(
    ${name}
    PROPERTIES
    IMPORTED_LOCATION ${location}
  )

  string(JSON len LENGTH "${json}" "//${target}" "include_dirs")

  foreach(i RANGE ${len})
    if(NOT i EQUAL len)
      string(JSON dir GET "${json}" "//${target}" "include_dirs" ${i})

      target_include_directories(${name} INTERFACE "${GN_DIR}${dir}")
    endif()
  endforeach()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "libs")

  if(error EQUAL "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON lib GET "${json}" "//${target}" "libs" ${i})

        target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:DEFAULT,${lib}>")
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "weak_frameworks")

  if(error EQUAL "NOTFOUND")
    foreach(i RANGE ${len})
      if(NOT i EQUAL len)
        string(JSON framework GET "${json}" "//${target}" "weak_frameworks" ${i})

        list(APPEND frameworks ${framework})

        target_link_libraries(${name} INTERFACE "$<LINK_LIBRARY:WEAK_FRAMEWORK,${framework}>")
      endif()
    endforeach()
  endif()

  string(JSON len ERROR_VARIABLE error LENGTH "${json}" "//${target}" "frameworks")

  if(error EQUAL "NOTFOUND")
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

function(find_gn result)
  find_program(gn NAMES gn)

  set(${result} ${gn})

  return(PROPAGATE ${result})
endfunction()
