/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <QListView>
#include <QItemSelectionModel>

QT_FORWARD_DECLARE_CLASS(QAbstractItemModel)

namespace P3::ProjectManager
{
    QT_FORWARD_DECLARE_CLASS(AdjustableHeaderWidget)

    class GemRepoListView
        : public QListView
    {
        Q_OBJECT

    public:
        explicit GemRepoListView(
                  QAbstractItemModel* model,
                  QItemSelectionModel* selectionModel,
                  AdjustableHeaderWidget* header,
                  QWidget* parent = nullptr);
        ~GemRepoListView() = default;

    signals:
        void RemoveRepo(const QModelIndex& modelIndex);
        void RefreshRepo(const QModelIndex& modelIndex);
    };
} // namespace P3::ProjectManager
