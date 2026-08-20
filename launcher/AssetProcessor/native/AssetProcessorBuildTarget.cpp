/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */
#include <AzCore/std/string/string_view.h>

namespace AssetProcessorBuildTarget
{
    //! This file is to be added only to the AssetProcessor build target
    //! This function returns the build system target name
    AZStd::string_view GetBuildTargetName()
    {
#if !defined (P3_CMAKE_TARGET)
#error "P3_CMAKE_TARGET must be defined in order to add this source file to a CMake executable target"
#endif
        return AZStd::string_view{ P3_CMAKE_TARGET };
    }
}
