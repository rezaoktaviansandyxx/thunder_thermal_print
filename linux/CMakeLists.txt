set(PLUGIN_NAME "thunder_thermal_print_plugin")

add_library(${PLUGIN_NAME} SHARED
  "thunder_thermal_print_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::CUPS)
target_link_libraries(${PLUGIN_NAME} PRIVATE usb-1.0)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}")
