// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//　通話とメッセージのプラットフォームとなる画面。通話とメッセージ画面の詳細設定はまた別のファイルにて。

#import "MUServerRootViewController.h"
#import "MUServerViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateViewController.h"
#import "MUNotificationController.h"
#import "MUConnectionController.h"
#import "MUDatabase.h"
#import "MUAudioMixerDebugViewController.h"
#import "MUOperatingSystem.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>
#import <MumbleKit/MKAudio.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>



// MUServerRootViewControllerクラスのインスタンス変数の定義------------------------
@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
    MKConnection                *_connection;
    MKServerModel               *_model;
    NSInteger                   _segmentIndex;
    //右上のボタン
    UIBarButtonItem             *_menuButton;
    // サーバービュー画面
    MUServerViewController      *_serverView;
    
    //通話画面の右上のメニューを開いた時のポップアップの配列
    //ここらへんはディスコネクト以外全部いらない。
    NSInteger                   _disconnectIndex;
    NSInteger                   _mixerDebugIndex;
}
@end

// MUServerRootViewControllerクラスメソッドの記述---------------------------------------
@implementation MUServerRootViewController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    
    if ((self = [super init])) {
        _connection = [conn retain];  //接続状態を保つ
        _model = [model retain];      //ひな形を保つ
        [_model addDelegate:self];
        
        //サーバービューのひな形を生成
        _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
    }
    
    return self;
}

// すべての解放------------------------------
- (void) dealloc {
    
    [_serverView release];
    [_model removeDelegate:self];
    [_model release];
    [_connection setDelegate:nil];
    [_connection release];
    [_menuButton release];

    [super dealloc];
}

- (void) takeOwnershipOfConnectionDelegate {
    [_connection setDelegate:self];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];

    //右上のメニューボタンの設定
    _menuButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"MumbleMenuButton"]
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(actionButtonClicked:)];
    
    _serverView.navigationItem.rightBarButtonItem = _menuButton;

    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
    
    //ナビゲーションバーがOSバージョンによって変化する設定
    UINavigationBar *navBar = self.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    self.toolbar.barStyle = UIBarStyleBlackOpaque;
}

- (void) viewDidUnload {
    [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // On iPad, we support all interface orientations.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -
#pragma mark setting for first responder


- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}



//------------------------------------------------------------------------------------------


#pragma mark - MKConnection delegate


// 詳細は不明-----------------------------------------------------------------
- (void) connectionOpened:(MKConnection *)conn {
}

- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
}

- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
}

- (void) connection:(MKConnection *)conn unableToConnectWithError:(NSError *)err {
}

- (void) connection:(MKConnection *)conn closedWithError:(NSError *)err {
    if (err) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                            message:[err localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];

        [[MUConnectionController sharedController] disconnectFromServer];
    }
}
//-------------------------------------------------------------------------------

#pragma mark - MKServerModel delegate

//詳細は不明-------------------------------------------------------------------------------------------------
- (void) serverModel:(MKServerModel *)model userKicked:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were kicked", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Kicked by %@ for reason: \"%@\"", @"Kicked by user for reason"),
                                    [actor userName], reasonMsg];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:alertMsg
                                                           delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model userBanned:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were banned", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Banned by %@ for reason: \"%@\"", nil),
                                    [actor userName], reasonMsg];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:alertMsg
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model permissionDenied:(MKPermission)perm forUser:(MKUser *)user inChannel:(MKChannel *)channel {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil)];
}

- (void) serverModelInvalidChannelNameError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Invalid channel name", nil)];
}

- (void) serverModelModifySuperUserError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Cannot modify SuperUser", nil)];
}

- (void) serverModelTextMessageTooLongError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Message too long", nil)];
}

- (void) serverModelTemporaryChannelError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Not permitted in temporary channel", nil)];
}

- (void) serverModel:(MKServerModel *)model missingCertificateErrorForUser:(MKUser *)user {
    if (user == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate", nil)];
    } else {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate for user", nil)];
    }
}

- (void) serverModel:(MKServerModel *)model invalidUsernameErrorForName:(NSString *)name {
    if (name == nil) {
        [[MUNotificationController sharedController] addNotification:@"Invalid username"];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:@"Invalid username: %@", name]];   
    }
}

- (void) serverModelChannelFullError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Channel is full", nil)];
}

- (void) serverModel:(MKServerModel *)model permissionDeniedForReason:(NSString *)reason {
    if (reason == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil)];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:
                                                                        NSLocalizedString(@"Permission denied: %@",
                                                                                          @"Permission denied with reason"),
                                                                        reason]];
    }
}

//-------------------------------------------------------------------------------------------------


#pragma mark - Actions

// メニューボタンを押した場合の設定-------------------------------------
- (void) actionButtonClicked:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    
    _disconnectIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Disconnect", nil)];
    [actionSheet setDestructiveButtonIndex:0];
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioMixerDebug"] boolValue]) {
        _mixerDebugIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Mixer Debug", nil)];
    } else {
        _mixerDebugIndex = -1;
    }
    
    NSInteger cancelIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [actionSheet setCancelButtonIndex:cancelIndex];
    
    [actionSheet setDelegate:self];
    [actionSheet showFromBarButtonItem:_menuButton animated:YES];
    [actionSheet release];
}


- (void) childDoneButton:(id)sender {
    [[self modalViewController] dismissModalViewControllerAnimated:YES];
}

//----------------------------------------------------------------------------------------------

#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // Self-Register
        [_model registerConnectedUser];
    }
}

#pragma mark - UIActionSheetDelegate

//メニューボタン押した時の設定のデリゲート-----------------------------------------------------------------------------
- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == [actionSheet cancelButtonIndex])
        return;

    if (buttonIndex == _disconnectIndex) { // Disconnect
        [[MUConnectionController sharedController] disconnectFromServer];
    } else if (buttonIndex == _mixerDebugIndex) {
        MUAudioMixerDebugViewController *audioMixerDebugViewController = [[MUAudioMixerDebugViewController alloc] init];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:audioMixerDebugViewController];
        [self presentModalViewController:navCtrl animated:YES];
        [audioMixerDebugViewController release];
        [navCtrl release];
    }
}
//-------------------------------------------------------------------------------------------------------------

@end
