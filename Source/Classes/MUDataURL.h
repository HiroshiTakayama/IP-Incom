// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// たぶんメッセージ機能を使う時にだけ必要なファイルかと。
// 送信時に一定のルールに従ってデータを文字に置換し、受信後に元のデータに復元(デコード)するという手法が取られるようになった。この置換ルールの一つがBASE64である。

@interface MUDataURL : NSObject
+ (NSData *) dataFromDataURL:(NSString *)dataURL;
+ (UIImage *) imageFromDataURL:(NSString *)dataURL;
@end
