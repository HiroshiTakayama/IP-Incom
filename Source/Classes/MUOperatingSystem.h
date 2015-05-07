// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// OSの管理。実際にこれが必要なのかどうかは不明

typedef NS_ENUM(NSInteger, MUOperatingSystemVersion) {
    MUMBLE_OS_UNKNOWN,
    
    MUMBLE_OS_IOS_5,
    MUMBLE_OS_IOS_6,
    MUMBLE_OS_IOS_7,
};

MUOperatingSystemVersion MUGetOperatingSystemVersion();