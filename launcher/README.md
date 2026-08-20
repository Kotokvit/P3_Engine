# P³ Engine Launcher (ребрендинг O3DE)

## Структура
```
launcher/
├── README.md              ← этот файл
├── GameLauncher/          ← исходники GameLauncher (228 KB бинарник)
│   ├── CMakeLists.txt     ← сборка через CMake
│   ├── Launcher.cpp       ← main lifecycle (654 строки)
│   ├── Launcher.h         ← PlatformMainInfo struct
│   ├── LauncherProject.cpp ← GetProjectName() / GetBuildTargetName()
│   ├── Unified.cpp         ← unified launcher (client + server)
│   ├── Game.cpp            ← game launcher (client only)
│   ├── Server.cpp          ← dedicated server
│   └── Platform/
│       ├── Linux/          ← Linux platform (Launcher_Linux.cpp — main())
│       ├── Windows/        ← Windows platform
│       ├── Mac/            ← macOS platform
│       ├── Android/        ← Android
│       ├── iOS/            ← iOS
│       └── Common/
│           └── UnixLike/   ← Unix-like shared code (resource limits)
└── (TODO) ProjectManager/  ← Qt-based Project Manager (позже)
└── (TODO) AssetProcessor/  ← background asset compiler (позже)
```

## Сборка

### Требования
- O3DE SDK (AzCore, AzFramework, AzGameFramework)
- CMake 3.22+
- GCC 11+ или Clang 14+

### Команды
```bash
# Указать путь к O3DE SDK
cmake -B build -S launcher/GameLauncher \
    -DO3DE_DIR=$HOME/.o3de/2.4.0

# Собрать
cmake --build build -j$(nproc)

# Запустить
./build/p3-game-launcher
```

## Ребрендинг выполнен
- `O3DELauncher` → `P3Launcher` (namespace)
- `O3DE` → `P3 Engine` (строки, комментарии)
- `Lumberyard` → `P3 Engine` (legacy совместимость)
- `CrySystem` → `P3System` (legacy совместимость)
- `LY_PROJECT_NAME` = `"P3Engine"`
- `LY_CMAKE_TARGET` = `p3-game-launcher`
- Лицензии сохранены (Apache 2.0 OR MIT)

## Интеграция с P³ Engine (Zig)

### Phase 1 (текущая): C++ лаунчер + Zig движок
- C++ GameLauncher запускает Zig-бинарники (`zig build run-race`, `zig build run-game`)
- Коммуникация через stdout/stdin (JSON observation)

### Phase 2 (следующая): настройка взаимодействия
- GameLauncher читает конфиг P3 Engine
- Запускает Zig-сцены напрямую
- Обработка ошибок Zig через C++ try/catch wrapper

### Phase 3 (будущее): полный перевод на Zig
- Замена C++ Launcher.cpp на `p3_launcher.zig` (raylib)
- Замена AzFramework на наш `p3_app.zig`
- Замена AzGameFramework на наш `p3_engine.zig`
