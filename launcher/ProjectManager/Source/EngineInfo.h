/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <QString>

namespace P3::ProjectManager
{
    class EngineInfo
    {
    public:
        EngineInfo() = default;
        EngineInfo(const QString& path, const QString& name, const QString& version, const QString& thirdPartyPath);
        bool operator<(const EngineInfo& engineInfo) const;

        // from engine.json
        QString m_version;
        QString m_displayVersion;
        QString m_name;

        QString m_thirdPartyPath;
        QString m_path;

        // from p3engine_manifest.json
        QString m_defaultProjectsFolder;
        QString m_defaultGemsFolder;
        QString m_defaultTemplatesFolder;
        QString m_defaultRestrictedFolder;

        bool m_registered = false;
        bool m_thisEngine = false;

        bool IsValid() const;
    };
} // namespace P3::ProjectManager
