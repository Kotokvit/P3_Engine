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
    QT_FORWARD_DECLARE_CLASS(AdjustableHeaderWidget)

    class GemListView
        : public QListView
    {
        Q_OBJECT

    public:
        explicit GemListView(QAbstractItemModel* model, QItemSelectionModel* selectionModel, AdjustableHeaderWidget* header, bool readOnly, QWidget* parent = nullptr);
        ~GemListView() = default;
    };
} // namespace P3::ProjectManager
