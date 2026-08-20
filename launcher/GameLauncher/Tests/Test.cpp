/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#include <AzCore/std/string/string_view.h>

// this is a mock P3 Engine Launcher implementation for unit tests and is used
// instead of LauncherProject.cpp.  If you modify LauncherProject.cpp or the interface launcher.h, make sure
// to update this file as well.

namespace P3Launcher
{
    bool WaitForAssetProcessorConnect()
    {
        return false;
    }

    bool IsDedicatedServer()
    {
        return false;
    }

    const char* GetLogFilename()
    {
        return "@log@/Game.log";
    }

    const char* GetLauncherTypeSpecialization()
    {
        return "client";
    }

    AZStd::string_view GetBuildTargetName()
    {
#if !defined (P3_CMAKE_TARGET)
#error "P3_CMAKE_TARGET must be defined in order to add this source file to a CMake executable target"
#endif
        return { P3_CMAKE_TARGET };
    }

    AZStd::string_view GetProjectName()
    {
        return { "Tests" };
    }

    AZStd::string_view GetProjectPath()
    {
        return { "Tests" };
    }

    bool IsGenericLauncher()
    {
        return false;
    }
}
