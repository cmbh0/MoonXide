import 'native_build_output_type.dart';

class NativeProjectTemplate {
  String cmake({required String projectName, required NativeBuildOutputType outputType}) {
    if (outputType == NativeBuildOutputType.executable || outputType == NativeBuildOutputType.shellExecutable) {
      final outputName = outputType == NativeBuildOutputType.shellExecutable ? '$projectName.sh' : projectName;
      return '''cmake_minimum_required(VERSION 3.22)
project($projectName C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
add_executable($projectName src/main.cpp)
set_target_properties($projectName PROPERTIES OUTPUT_NAME "$outputName")
''';
    }
    return '''cmake_minimum_required(VERSION 3.22)
project($projectName C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
add_library($projectName ${outputType.cmakeLibraryKind} src/main.cpp)
''';
  }

  String mainCpp(NativeBuildOutputType outputType) {
    if (outputType == NativeBuildOutputType.executable || outputType == NativeBuildOutputType.shellExecutable) {
      return '''#include <iostream>

int main() {
    std::cout << "Hello from native executable" << std::endl;
    return 0;
}
''';
    }
    return '''extern "C" int moonxide_add(int a, int b) {
    return a + b;
}
''';
  }

  String workflow() => r'''name: native-build

on:
  workflow_dispatch:
    inputs:
      build_type:
        description: Build type
        required: true
        default: release
        type: choice
        options:
          - debug
          - release

jobs:
  build-native:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install build tools
        run: sudo apt-get update && sudo apt-get install -y cmake ninja-build build-essential
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=${{ github.event.inputs.build_type == 'debug' && 'Debug' || 'Release' }}
      - name: Build
        run: cmake --build build --config ${{ github.event.inputs.build_type == 'debug' && 'Debug' || 'Release' }}
      - name: Make executable artifacts runnable
        run: find build -type f -name "*.sh" -exec chmod +x {} \;
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: native-${{ github.event.inputs.build_type }}
          path: build/**
''';
}