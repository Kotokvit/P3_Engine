/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <QDialog>

namespace P3::ProjectManager
{
    QT_FORWARD_DECLARE_CLASS(FormLineEditWidget)

    class GemRepoAddDialog
        : public QDialog
    {
    public:
        explicit GemRepoAddDialog(QWidget* parent = nullptr);
        ~GemRepoAddDialog() = default;

        QString GetRepoPath();

    private:
        FormLineEditWidget* m_repoPath = nullptr;
    };
} // namespace P3::ProjectManager
