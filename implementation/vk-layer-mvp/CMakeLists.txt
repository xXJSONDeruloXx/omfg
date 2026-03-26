cmake_minimum_required(VERSION 3.20)
project(ppfg_vk_layer_mvp VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(VkLayer_PPFG_mvp SHARED
  src/layer.cpp
)

find_package(Vulkan REQUIRED)

target_include_directories(VkLayer_PPFG_mvp
  PRIVATE
    ${Vulkan_INCLUDE_DIRS}
)

target_link_libraries(VkLayer_PPFG_mvp
  PRIVATE
    Vulkan::Vulkan
    dl
)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(VkLayer_PPFG_mvp PRIVATE
    -Wall -Wextra -Wpedantic
    -Wno-missing-field-initializers
  )
  target_link_options(VkLayer_PPFG_mvp PRIVATE
    -static-libstdc++
    -static-libgcc
  )
endif()

set_target_properties(VkLayer_PPFG_mvp PROPERTIES
  OUTPUT_NAME "VkLayer_PPFG_mvp"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
)

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/layer/VkLayer_PPFG_mvp.json.in
  ${CMAKE_BINARY_DIR}/out/VkLayer_PPFG_mvp.json
  @ONLY
)
