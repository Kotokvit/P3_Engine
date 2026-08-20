/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#pragma once

#include <ProjectTemplateInfo.h>

#include <QDialog>

QT_FORWARD_DECLARE_CLASS(QLabel)
QT_FORWARD_DECLARE_CLASS(QDialogButtonBox)
QT_FORWARD_DECLARE_CLASS(QPushButton)

namespace P3::ProjectManager
{
    QT_FORWARD_DECLARE_CLASS(FormLineEditWidget)

    class DownloadRemoteTemplateDialog
        : public QDialog
    {
        Q_OBJECT

    public:
        explicit DownloadRemoteTemplateDialog(const ProjectTemplateInfo& projectTemplate, QWidget* parent = nullptr);
        ~DownloadRemoteTemplateDialog() = default;

        QString GetInstallPath();

    signals:
        void StartObjectDownload(const QString& objectName);

    private:
        FormLineEditWidget* m_installPath = nullptr;

        QLabel* m_buildToggleLabel = nullptr;

        QLabel* m_downloadTemplateLabel = nullptr;

        QLabel* m_requirementsTitleLabel = nullptr;
        QLabel* m_licensesTitleLabel = nullptr;

        QLabel* m_requirementsContentLabel = nullptr;
        QLabel* m_licensesContentLabel = nullptr;

        QDialogButtonBox* m_dialogButtons = nullptr;
        QPushButton* m_applyButton = nullptr;
    };
} // namespace P3::ProjectManager
