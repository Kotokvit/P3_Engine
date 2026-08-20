/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <GemCatalog/GemItemDelegate.h>


namespace P3::ProjectManager
{
    class GemRequirementDelegate
        : public GemItemDelegate
    {
        Q_OBJECT

    public:
        explicit GemRequirementDelegate(QAbstractItemModel* model, QObject* parent = nullptr);
        ~GemRequirementDelegate() = default;

        void paint(QPainter* painter, const QStyleOptionViewItem& option, const QModelIndex& modelIndex) const override;
        bool editorEvent(QEvent* event, QAbstractItemModel* model, const QStyleOptionViewItem& option, const QModelIndex& modelIndex) override;

        const QColor m_backgroundColor = QColor("#444444"); // Outside of the actual gem item
        const QColor m_itemBackgroundColor = QColor("#393939"); // Background color of the gem item

    private:
        QRect CalcRequirementRect(const QRect& contentRect) const;
    };
} // namespace P3::ProjectManager
