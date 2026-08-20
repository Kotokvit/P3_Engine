/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */
#pragma once

#include <ScreenDefs.h>

#include <QWidget>

namespace P3::ProjectManager
{
    QT_FORWARD_DECLARE_CLASS(ScreenWidget);
    QT_FORWARD_DECLARE_CLASS(DownloadController);

    ScreenWidget* BuildScreen(QWidget* parent = nullptr, ProjectManagerScreen screen = ProjectManagerScreen::Empty, DownloadController* downloadController = nullptr);
} // namespace P3::ProjectManager
