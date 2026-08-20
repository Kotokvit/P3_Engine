/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <QAbstractItemModel>
#include <QItemSelectionModel>
#include <QListView>

namespace P3::ProjectManager
{
    class GemRequirementListView
        : public QListView
    {
        Q_OBJECT

    public:
        explicit GemRequirementListView(QAbstractItemModel* model, QItemSelectionModel* selectionModel, QWidget* parent = nullptr);
        ~GemRequirementListView() = default;
    };
} // namespace P3::ProjectManager
