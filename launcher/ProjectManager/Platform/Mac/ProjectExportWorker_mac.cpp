/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#include <ProjectExportWorker.h>
#include <ProjectManagerDefs.h>
#include <ProjectUtils.h>

#include <QDir>
#include <QString>

namespace P3::ProjectManager
{
    QString ProjectExportWorker::GetO3DECLIString() const
    {
        return QString("scripts/p3engine.sh");
    }
    AZ::Outcome<QStringList, QString> ProjectExportWorker::ConstructKillProcessCommandArguments(const QString& pidToKill) const
    {
        return AZ::Success(QStringList{"kill", "-9", pidToKill});
    }

} // namespace P3::ProjectManager
