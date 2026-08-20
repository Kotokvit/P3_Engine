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
    QT_FORWARD_DECLARE_CLASS(GemModel)

    class GemRequirementDialog
        : public QDialog
    {
        Q_OBJECT
    public:
        explicit GemRequirementDialog(GemModel* model, QWidget *parent = nullptr);
        ~GemRequirementDialog() = default;
    };
} // namespace P3::ProjectManager
