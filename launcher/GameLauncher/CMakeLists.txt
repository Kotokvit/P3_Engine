# =============================================================================
# P³ ENGINE — GameLauncher (ребрендинг O3DE GameLauncher)
# =============================================================================
# Сборка: требует установленный O3DE SDK (AzCore, AzFramework, AzGameFramework)
# cmake -B build -S . -DO3DE_DIR=/path/to/o3de
# cmake --build build
# =============================================================================

cmake_minimum_required(VERSION 3.22)
project(P3GameLauncher LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# O3DE SDK путь (укажите свой)
if(NOT DEFINED O3DE_DIR)
    set(O3DE_DIR "$ENV{HOME}/.o3de/2.4.0" CACHE PATH "Path to O3DE installation")
endif()

# Исходники (только Linux платформа)
set(LAUNCHER_SOURCES
    Launcher.cpp
    Launcher.h
    LauncherProject.cpp
    Unified.cpp
    Game.cpp
    Server.cpp
    Platform/Linux/Launcher_Linux.cpp
    Platform/Linux/Launcher_Traits_Linux.h
    Platform/Linux/Launcher_Traits_Platform.h
    Platform/Common/UnixLike/Launcher_UnixLike.cpp
    Platform/Common/UnixLike/Launcher_UnixLike.h
)

add_executable(p3-game-launcher ${LAUNCHER_SOURCES})

# Линки к O3DE библиотекам
target_include_directories(p3-game-launcher PRIVATE
    ${O3DE_DIR}/Code/Source
    ${O3DE_DIR}/Code/Source/CryCommon
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(p3-game-launcher PRIVATE
    ${O3DE_DIR}/lib/libAzCore.a
    ${O3DE_DIR}/lib/libAzFramework.a
    ${O3DE_DIR}/lib/libAzGameFramework.a
    ${O3DE_DIR}/lib/libAzComponentFramework.a
)

# Системные библиотеки
target_link_libraries(p3-game-launcher PRIVATE
    dl rt pthread X11 GL
)

# Компиляторные дефайны
target_compile_definitions(p3-game-launcher PRIVATE
    P3_IS_GENERIC_LAUNCHER
    LY_PROJECT_NAME="P3Engine"
    AZ_MONOLITHIC_BUILD
)
