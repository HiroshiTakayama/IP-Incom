// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// リモートコントロールサーバーの設定だが、これを何に使っているかわからない
// 調べてみたけどこれがなくても、使用上は問題ありません。

@interface MURemoteControlServer : NSObject
+ (MURemoteControlServer *) sharedRemoteControlServer;
- (BOOL) isRunning;
- (BOOL) start;
- (BOOL) stop;
@end
