// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// サーバー接続の要になる部分。IPアドレスやポートの設定など？


extern NSString *MUConnectionOpenedNotification;
extern NSString *MUConnectionClosedNotification;

/*他のファイルの変数を参照するときは
 
 １．externを付けて宣言しましょう（定義（初期化）してはダメ）。
 ２．同じ識別子（名前）のオブジェクト（変数）を同ファイル内で定義してはいけません。
 ３．ちなみに、宣言は何度されても一貫性がある限り問題ありません。
 
*/

@interface MUConnectionController : UIView
+ (MUConnectionController *) sharedController;
- (void) connetToHostname:(NSString *)hostName   port:(NSUInteger)port   withUsername:(NSString *)userName   andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController;
- (BOOL) isConnected;
- (void) disconnectFromServer;
@end
