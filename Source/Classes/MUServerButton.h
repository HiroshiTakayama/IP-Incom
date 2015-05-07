// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// サーバーリストの細かい表示の設定箇所。msとかpplとか、port表示とか。これ凄い細かいけどいらない。

#import "MUFavouriteServer.h"

@interface MUServerButton : UIControl
- (void) populateFromDisplayName:(NSString *)displayName hostName:(NSString *)hostName port:(NSString *)port;
- (void) populateFromFavouriteServer:(MUFavouriteServer *)favServ;
@end
