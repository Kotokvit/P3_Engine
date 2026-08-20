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
    class GemUpdateDialog
        : public QDialog
    {
        Q_OBJECT
    public :
        explicit GemUpdateDialog(const QString& gemName, bool updateAvaliable = true, QWidget* parent = nullptr);
        ~GemUpdateDialog() = default;
    };
} // namespace P3::ProjectManager
