// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// たぶんログイン後の音声通信画面。話している時の状態変化や誰がログイン中か、など書いていると思う。


#import <MumbleKit/MKServerModel.h>

typedef enum {
    MUServerViewControllerViewModeServer = 0,
} MUServerViewControllerViewMode;


@interface MUServerViewController : UITableViewController
- (id) initWithServerModel:(MKServerModel *)serverModel;
- (void) toggleMode;

@end