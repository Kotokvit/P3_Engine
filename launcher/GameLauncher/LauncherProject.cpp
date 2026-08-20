/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

// note that this is the only file pulled into a launcher target that has the
// defines set such as P3_CMAKE_TARGET, and P3_PROJECT_NAME, other files come from a static library
// which do not provide those defines.
// note that the tests use a mock implementation of this file, see Tests/Test.cpp
// If you modify this file or the interface launcher.h, make sure to update the mock implementation as well.

#include <AzCore/std/string/string_view.h>

#if defined(AZ_MONOLITHIC_BUILD)
    #include <StaticModules.inl>
#endif //  defined(AZ_MONOLITHIC_BUILD)

namespace P3Launcher
{
    //! This file is to be added only to the ${project}.[Game|Server]Launcher build target
    //! This function returns the build system target name
    AZStd::string_view GetBuildTargetName()
    {
#if !defined (P3_CMAKE_TARGET)
#error "P3_CMAKE_TARGET must be defined in order to add this source file to a CMake executable target"
#endif
        return { P3_CMAKE_TARGET };
    }


    AZStd::string_view GetProjectName()
    {
#if !defined (P3_PROJECT_NAME)
#error "P3_PROJECT_NAME must be defined in order to for the Launcher to run using a Game Project"
#endif
        return { P3_PROJECT_NAME };
    }

    bool IsGenericLauncher()
    {
#if defined(P3_IS_GENERIC_LAUNCHER)
        return true;
#else
        return false;
#endif
    }
}
