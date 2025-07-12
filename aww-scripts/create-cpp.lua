-- create-cpp.lua: A self-extracting script to recreate a C++ project template.
-- Usage: lua create-cpp.lua

--[[ KUDOS:
This project was highly inspired from “bsamseth/cpp-project”:
https://github.com/bsamseth/cpp-project
Boiler plate template for C++ projects, with CMake, Doctest, Travis CI, Appveyor, GitHub Actions and coverage reports
License: Unlicense
]]

local files = {
  ["CMakeLists.txt"] = [=[
cmake_minimum_required(VERSION 3.15)

# To rename the project, change the project name here and in the add_executable command below.
project(my_project VERSION 1.0.0 LANGUAGES CXX)

# Set output directories for executables and libraries.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# For multi-config generators, set per-config output directories
if(DEFINED CMAKE_CONFIGURATION_TYPES)
  foreach(CONFIG ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG} CONFIG_UPPER)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG_UPPER} ${CMAKE_CURRENT_SOURCE_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG_UPPER} ${CMAKE_CURRENT_SOURCE_DIR})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_UPPER} ${CMAKE_CURRENT_SOURCE_DIR})
  endforeach()
endif()

# Include CMake modules from the 'cmake' directory.
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")
include(ConfigSafeGuards)
include(Colors)
include(LTO)
include(Warnings)

# Generate compile_commands.json for tooling support.
set(CMAKE_EXPORT_COMPILE_COMMANDS 1)

# Check for Link Time Optimization (LTO) support.
find_lto(CXX)

# Add the main executable from main.cpp.
add_executable(my_project_app main.cpp)

# Set output name and other properties for the executable.
string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" COMPILER_ID_LOWER)
set_target_properties(my_project_app
    PROPERTIES
    OUTPUT_NAME "$<LOWER_CASE:$<CONFIG>>_${COMPILER_ID_LOWER}_main"
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

# Apply warning settings and LTO to the executable.
target_set_warnings(my_project_app ENABLE ALL AS_ERROR ALL DISABLE Annoying)
target_enable_lto(my_project_app optimized)

# Suppress specific warnings for MSVC.
if(MSVC)
    target_compile_options(my_project_app PRIVATE /wd4244)
endif()

# Display a summary message to the user.
message(STATUS "===================================================================")
message(STATUS "${Green}Project: ${PROJECT_NAME}${ColorReset}")
message(STATUS "${Green}Version: ${PROJECT_VERSION}${ColorReset}")
message(STATUS "${Green}Build type: ${CMAKE_BUILD_TYPE}${ColorReset}")
message(STATUS "===================================================================")
]=],
  ["main.cpp"] = [=[
#include "main.hpp"
#include <iostream>

int main() {
    std::cout << "Hello, world!" << std::endl;
    return 0;
}
]=],
  ["main.hpp"] = [=[
#pragma once

// Add your declarations here
]=],
  ["build-debug-on-linux.sh"] = [=[
#!/bin/env bash
cmake -B build-debug -S . -DCMAKE_BUILD_TYPE=Debug && cmake --build build-debug -j --config Debug
]=],
  ["build-debug-on-windows.cmd"] = [=[
@echo off
set BUILD_DIR=build-debug
cmake -B %BUILD_DIR% -S . -DCMAKE_BUILD_TYPE=Debug && ^
cmake --build %BUILD_DIR% -j --config Debug
]=],
  ["build-release-on-linux.sh"] = [=[
#!/bin/env bash
cmake -B build-release -S . -DCMAKE_BUILD_TYPE=Release && cmake --build build-release -j --config Release
]=],
  ["build-release-on-windows.cmd"] = [=[
@echo off
set BUILD_DIR=build-release
cmake -B %BUILD_DIR% -S . -DCMAKE_BUILD_TYPE=Release && ^
cmake --build %BUILD_DIR% -j --config Release
]=],
  ["cmake/Colors.cmake"] = [=[
IF(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColorReset "${Esc}[m")
  set(ColorBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
ENDIF()
]=],
  ["cmake/ConfigSafeGuards.cmake"] = [=[
# guard against in-source builds
if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there.")
endif()

# guard against bad build-type strings
if (NOT CMAKE_BUILD_TYPE)
    message(STATUS "No build type selected, default to Debug")
    set(CMAKE_BUILD_TYPE "Debug")
endif()

string(TOLOWER "${CMAKE_BUILD_TYPE}" cmake_build_type_tolower)
string(TOUPPER "${CMAKE_BUILD_TYPE}" cmake_build_type_toupper)
if(    NOT cmake_build_type_tolower STREQUAL "debug"
   AND NOT cmake_build_type_tolower STREQUAL "release"
   AND NOT cmake_build_type_tolower STREQUAL "profile"
   AND NOT cmake_build_type_tolower STREQUAL "relwithdebinfo"
   AND NOT cmake_build_type_tolower STREQUAL "coverage")
      message(FATAL_ERROR "Unknown build type \"${CMAKE_BUILD_TYPE}\". Allowed values are Debug, Coverage, Release, Profile, RelWithDebInfo (case-insensitive).")
endif()
]=],
  ["cmake/LTO.cmake"] = [=[
# Simplified LTO module for CMake 3.9+
# Usage:
# find_lto(CXX)
# target_enable_lto(my_target optimized)

macro(find_lto lang)
    if(NOT LTO_${lang}_CHECKED)
        cmake_policy(SET CMP0069 NEW)
        include(CheckIPOSupported)
        check_ipo_supported(RESULT __IPO_SUPPORTED OUTPUT output)
        if(__IPO_SUPPORTED)
            message(STATUS "LTO/IPO is supported.")
        else()
            message(STATUS "LTO/IPO is not supported.")
        endif()
        set(LTO_${lang}_CHECKED TRUE CACHE INTERNAL "")
    endif()

    if(__IPO_SUPPORTED)
        macro(target_enable_lto _target _build_configuration)
            if(NOT ${_build_configuration} STREQUAL "debug" )
                set_target_properties(${_target} PROPERTIES INTERPROCEDURAL_OPTIMIZATION TRUE)
            endif()
            if(${_build_configuration} STREQUAL "optimized" )
                get_property(DEBUG_CONFIGURATIONS GLOBAL PROPERTY DEBUG_CONFIGURATIONS)
                if(NOT DEBUG_CONFIGURATIONS)
                    set(DEBUG_CONFIGURATIONS DEBUG)
                endif()
                foreach(config IN LISTS DEBUG_CONFIGURATIONS)
                    set_target_properties(${_target} PROPERTIES INTERPROCEDURAL_OPTIMIZATION_${config} FALSE)
                endforeach()
            endif()
        endmacro()
    else()
        macro(target_enable_lto _target _build_configuration)
            # LTO not supported, do nothing.
        endmacro()
    endif()
endmacro()
]=],
  ["cmake/Warnings.cmake"] = [=[
# MIT License

# Copyright (c) 2017 Lectem

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


function(target_set_warnings)
    if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
      set(WMSVC TRUE)
    elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
      set(WGCC TRUE)
    elseif ("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang")
      set(WCLANG TRUE)
    endif()
    set(multiValueArgs ENABLE DISABLE AS_ERROR)
    cmake_parse_arguments(this "" "" "${multiValueArgs}" ${ARGN})
    list(FIND this_ENABLE "ALL" enable_all)
    list(FIND this_DISABLE "ALL" disable_all)
    list(FIND this_AS_ERROR "ALL" as_error_all)
    if(NOT ${enable_all} EQUAL -1)
      if(WMSVC)
        # Not all the warnings, but WAll is unusable when using libraries
        # Unless you'd like to support MSVC in the code with pragmas, this is probably the best option
        list(APPEND WarningFlags "/W4")
      elseif(WGCC)
        list(APPEND WarningFlags "-Wall" "-Wextra" "-Wpedantic")
      elseif(WCLANG)
        list(APPEND WarningFlags "-Wall" "-Weverything" "-Wpedantic")
      endif()
    elseif(NOT ${disable_all} EQUAL -1)
      set(SystemIncludes TRUE) # Treat includes as if coming from system
      if(WMSVC)
        list(APPEND WarningFlags "/w" "/W0")
      elseif(WGCC OR WCLANG)
        list(APPEND WarningFlags "-w")
      endif()
    endif()

    list(FIND this_DISABLE "Annoying" disable_annoying)
    if(NOT ${disable_annoying} EQUAL -1)
      if(WMSVC)
        # bounds-checked functions require to set __STDC_WANT_LIB_EXT1__ which we usually don't need/want
        list(APPEND WarningDefinitions -D_CRT_SECURE_NO_WARNINGS)
      elseif(WGCC OR WCLANG)
        list(APPEND WarningFlags -Wno-switch-enum)
        if(WCLANG)
          list(APPEND WarningFlags -Wno-unknown-warning-option -Wno-padded -Wno-undef -Wno-reserved-id-macro -fcomment-block-commands=test,retval)
          if ("${CMAKE_CXX_SIMULATE_ID}" STREQUAL "MSVC") # clang-cl has some VCC flags by default that it will not recognize...
              list(APPEND WarningFlags -Wno-unused-command-line-argument)
          endif()
        endif(WCLANG)
      endif()
    endif()

    if(NOT ${as_error_all} EQUAL -1)
      if(WMSVC)
        list(APPEND WarningFlags "/WX")
      elseif(WGCC OR WCLANG)
        list(APPEND WarningFlags "-Werror")
      endif()
    endif()
    foreach(target IN LISTS this_UNPARSED_ARGUMENTS)
      if(WarningFlags)
        target_compile_options(${target} PRIVATE ${WarningFlags})
      endif()
      if(WarningDefinitions)
        target_compile_definitions(${target} PRIVATE ${WarningDefinitions})
      endif()
      if(SystemIncludes)
        set_target_properties(${target} PROPERTIES
            INTERFACE_SYSTEM_INCLUDE_DIRECTORIES $<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>)
      endif()
    endforeach()
endfunction(target_set_warnings)
]=],
}

-- Function to create directories
function create_dir(path)
  -- For Lua 5.4, os.execute is the standard way to do this.
  -- We'll create directories one by one.
  local parts = {}
  for part in path:gmatch("([^/\\]+)") do
    table.insert(parts, part)
    local current_path = table.concat(parts, "/")
    -- lfs.mkdir doesn't exist in standard lua, so we use os.execute
    -- The command to create a directory if it doesn't exist varies by OS.
    if package.config:sub(1,1) == '\\' then -- Windows
        os.execute('if not exist "' .. current_path .. '" mkdir "' .. current_path .. '"')
    else -- POSIX
        os.execute('mkdir -p "' .. current_path .. '"')
    end
  end
end

-- Main logic to write files
for path, content in pairs(files) do
  local dir_path = path:match("(.+)/") or path:match("(.+)\\")
  if dir_path then
    create_dir(dir_path)
  end

  local file, err = io.open(path, "w")
  if file then
    print("Creating file: " .. path)
    file:write(content)
    file:close()
  else
    print("Error creating file " .. path .. ": " .. tostring(err))
  end
end

print("Project recreation complete.")
print("You can now use the build scripts (e.g., build-release-on-windows.cmd or ./build-release-on-linux.sh).")
