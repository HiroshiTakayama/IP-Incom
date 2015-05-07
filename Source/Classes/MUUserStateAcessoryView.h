// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// // 接続中に右上のメニューを選んだ後に、ミュートなどを選択したら小さいアイコンが出てくるけど、そこをどんなものを表示するかの設定。ここはいらない。


@class MKUser;

@interface MUUserStateAcessoryView : NSObject
+ (UIView *) viewForUser:(MKUser *)user;
@end
