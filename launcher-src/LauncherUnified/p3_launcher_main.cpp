// =============================================================================
// P³ ENGINE — NATIVE C++ LAUNCHER ENTRY POINT (SOURCE BUILD)
// =============================================================================
// Этот файл компилируется напрямую из исходников через Zig C++ Toolchain:
//   - Инициализирует лимиты ресурсов ОС через P3_O3DE_Bridge
//   - Запускает главный цикл P³ Native Launcher
// =============================================================================

#include "../../include/p3_bridge.h"
#include <iostream>

int main(int argc, char** argv)
{
    (void)argc;
    (void)argv;
    std::cout << "⚡ [P³ Engine Launcher - Source Build]" << std::endl;
    std::cout << "Bridge Version: " << P3_GetBridgeVersion() << std::endl;

    // 1. Инициализация лимитов ОС
    O3DELauncher_IncreaseResourceLimits();

    // 2. Запуск нативного главного цикла P³
    uint8_t res = O3DELauncher_RunNative("/opt/O3DE/26.05", "/home/vitalij/o3de_game_project");
    std::cout << "P3 Launcher Run Result: " << (int)res << " (Success)" << std::endl;
    return res;
}
