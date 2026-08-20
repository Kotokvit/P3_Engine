/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

namespace P3Launcher
{
    bool WaitForAssetProcessorConnect()
    {
        return true;
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
}
