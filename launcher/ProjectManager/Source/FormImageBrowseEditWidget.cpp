/*
 * Copyright (c) Contributors to the P3 Engine Project.
 * For complete copyright and license terms please see the LICENSE at the root of this distribution.
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 */

#include <FormImageBrowseEditWidget.h>
#include <AzQtComponents/Components/StyledLineEdit.h>

#include <QFileDialog>
#include <QLineEdit>

namespace P3::ProjectManager
{
    FormImageBrowseEditWidget::FormImageBrowseEditWidget(const QString& labelText, const QString& valueText, QWidget* parent)
        : FormBrowseEditWidget(labelText, valueText, parent)
    {
    }

    void FormImageBrowseEditWidget::HandleBrowseButton()
    {
        QString file = QDir::toNativeSeparators(QFileDialog::getOpenFileName(
            this, tr("Select Image"), m_lineEdit->text(), tr("PNG (*.png)")));
        if (!file.isEmpty())
        {
            m_lineEdit->setText(file);
        }
    }
} // namespace P3::ProjectManager
