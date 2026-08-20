/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#include <GemCatalog/GemRequirementListView.h>
#include <GemCatalog/GemRequirementDelegate.h>

namespace P3::ProjectManager
{
    GemRequirementListView::GemRequirementListView(QAbstractItemModel* model, QItemSelectionModel* selectionModel, QWidget* parent)
        : QListView(parent)
    {
        setVerticalScrollMode(QAbstractItemView::ScrollPerPixel);

        setStyleSheet("background-color: #444444;");

        setModel(model);
        setSelectionModel(selectionModel);
        setItemDelegate(new GemRequirementDelegate(model, this));
    }
} // namespace P3::ProjectManager
