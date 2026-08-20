# =============================================================================
# P³ ENGINE LAUNCHER — CMake build (refactored O3DE launcher source)
# =============================================================================
# Сборка: cmake -B build -S launcher -DO3DE_DIR=/opt/O3DE/26.05
# =============================================================================
cmake_minimum_required(VERSION 3.22)
project(P3EngineLauncher LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# O3DE SDK путь
if(NOT DEFINED O3DE_DIR)
    set(O3DE_DIR "/opt/O3DE/26.05" CACHE PATH "Path to O3DE installation")
endif()

message(STATUS "P³ Engine Launcher")
message(STATUS "  O3DE SDK: ${O3DE_DIR}")

# Подпроекты
add_subdirectory(GameLauncher)
# add_subdirectory(ProjectManager)  # TODO: requires Qt5/Qt6
# add_subdirectory(AssetProcessor)  # TODO: requires AzCore full build
# add_subdirectory(Editor)          # TODO: requires full Editor framework
