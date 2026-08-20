/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <GemCatalog/GemFilterTagWidget.h>
#include <GemCatalog/GemSortFilterProxyModel.h>

#include <QFrame>

namespace P3::ProjectManager
{
    class GemListHeaderWidget
        : public QFrame
    {
        Q_OBJECT

    public:
        explicit GemListHeaderWidget(GemSortFilterProxyModel* proxyModel, QWidget* parent = nullptr);
        ~GemListHeaderWidget() = default;

    signals:
        void OnRefresh(bool refreshRemoteRepos);
    };
} // namespace P3::ProjectManager
