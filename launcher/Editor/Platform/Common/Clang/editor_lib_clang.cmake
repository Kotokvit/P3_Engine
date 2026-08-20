#
# Copyright (c) Contributors to the P3 Engine Project.
# For complete copyright and license terms please see the LICENSE at the root of this distribution.
#
# SPDX-License-Identifier: Apache-2.0 OR MIT
#
#
if(MSVC)
    set(P3_COMPILE_OPTIONS PRIVATE /EHsc)
else()
    set(P3_COMPILE_OPTIONS PRIVATE -fexceptions)
endif()
