// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// キーボードの表示・非表示は、NSNotificationCenterオブジェクトを介して行う
// 画面のサイズを取得して、キーボードのUIを自動的に変更するためのメソッドを書いている。ここは使わない。


#import <Foundation/Foundation.h>

@interface MUNotificationController : NSObject
+ (MUNotificationController *) sharedController;
- (void) addNotification:(NSString *)text;
@end
