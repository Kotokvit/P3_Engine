/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */
#pragma once

#include <ScreenWidget.h>

QT_FORWARD_DECLARE_CLASS(QStackedWidget)

namespace P3::ProjectManager
{
    QT_FORWARD_DECLARE_CLASS(ScreenHeader)
    QT_FORWARD_DECLARE_CLASS(GemRepoScreen)

    //! A wrapper for a GemRepoScreen with a header that has a back button
    class GemsGemRepoScreen
        : public ScreenWidget
    {
    public:
        explicit GemsGemRepoScreen(QWidget* parent = nullptr);
        ~GemsGemRepoScreen() = default;

        ProjectManagerScreen GetScreenEnum() override;

    protected slots:
        void HandleBackButton();

    private:
        GemRepoScreen* m_gemRepoScreen = nullptr;
        ScreenHeader* m_header = nullptr;
    };

} // namespace P3::ProjectManager
