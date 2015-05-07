// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// メッセージ機能の設定。実際はこれは使わない。

@interface MUMessagesViewController : UIViewController
- (id) initWithServerModel:(MKServerModel *)model;
- (void) clearAllMessages;
@end
