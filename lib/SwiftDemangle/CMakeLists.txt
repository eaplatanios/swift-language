add_swift_host_library(swiftDemangle SHARED
  SwiftDemangle.cpp
  MangleHack.cpp)
target_compile_definitions(swiftDemangle PRIVATE
  LLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1)
target_link_libraries(swiftDemangle PRIVATE
  swiftDemangling)

swift_install_in_component(TARGETS swiftDemangle
  LIBRARY
    DESTINATION "lib${LLVM_LIBDIR_SUFFIX}"
    COMPONENT compiler
  ARCHIVE
    DESTINATION "lib${LLVM_LIBDIR_SUFFIX}"
    COMPONENT compiler)
