// =============================================================================
// P³ ENGINE — PATCHED O3DE LAUNCHER APPLICATION SOURCE (C++17)
// =============================================================================
// Этот файл — пропатченный C++ исходник оригинального LauncherUnified O3DE.
// Все тяжеловесные монолитные зависимости (CrySystem, EBus, RTTI) заменены
// на прямые легковесные вызовы нативного C-ABI моста P³ Engine:
//   - Управление лимитами ОС
//   - Нативная инициализация приложения и VFS
//   - Загрузка префаба уровня (.spawnable)
//   - Запуск игрового цикла
// =============================================================================

#include "../../include/p3_bridge.h"
#include <iostream>
#include <string>
#include <vector>

namespace O3DE_Patched
{
    class LauncherApp
    {
    public:
        LauncherApp(int argc, char** argv)
            : m_argc(argc)
            , m_argv(argv)
            , m_enginePath("/opt/O3DE/26.05")
            , m_projectPath("/home/vitalij/o3de_game_project")
        {
            parseCommandLine();
        }

        int Run()
        {
            std::cout << "=================================================" << std::endl;
            std::cout << "🚀 O3DE Launcher (Patched Native Source Build)" << std::endl;
            std::cout << "   Bridge: " << P3_GetBridgeVersion() << std::endl;
            std::cout << "   Engine Path: " << m_enginePath << std::endl;
            std::cout << "   Project Path: " << m_projectPath << std::endl;
            std::cout << "=================================================" << std::endl;

            // 1. Увеличение системных лимитов дескрипторов и стека ОС
            O3DELauncher_IncreaseResourceLimits();

            // 2. Инициализация курсора
            void* cursorMgr = P3_Cursor_Create();
            if (cursorMgr)
            {
                P3_Cursor_SetSystemCursorState(cursorMgr, 4); // UnconstrainedAndVisible
                P3_Cursor_IncrementVisibleCounter(cursorMgr);
            }

            // 3. Запуск нативного главного цикла P³
            uint8_t result = O3DELauncher_RunNative(m_enginePath.c_str(), m_projectPath.c_str());

            if (cursorMgr)
            {
                P3_Cursor_Destroy(cursorMgr);
            }

            return result;
        }

    private:
        void parseCommandLine()
        {
            for (int i = 1; i < m_argc; ++i)
            {
                std::string arg = m_argv[i];
                if ((arg == "--project-path" || arg == "-p") && i + 1 < m_argc)
                {
                    m_projectPath = m_argv[++i];
                }
                else if ((arg == "--engine-path" || arg == "-e") && i + 1 < m_argc)
                {
                    m_enginePath = m_argv[++i];
                }
            }
        }

        int m_argc;
        char** m_argv;
        std::string m_enginePath;
        std::string m_projectPath;
    };
}

// Точка входа лаунчера O3DE
int main(int argc, char** argv)
{
    O3DE_Patched::LauncherApp app(argc, argv);
    return app.Run();
}
