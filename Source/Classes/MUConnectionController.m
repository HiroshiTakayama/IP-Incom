// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// サーバー接続の要になる部分。IPアドレスやポートの設定など？

#import "MUConnectionController.h"
#import "MUServerRootViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUDatabase.h"
#import "MUOperatingSystem.h"
#import "MUHorizontalFlipTransitionDelegate.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>

NSString *MUConnectionOpenedNotification = @"MUConnectionOpenedNotification";
NSString *MUConnectionClosedNotification = @"MUConnectionClosedNotification";

@interface MUConnectionController () <MKConnectionDelegate, MKServerModelDelegate, MUServerCertificateTrustViewControllerProtocol> {
    MKConnection               *_connection;
    MKServerModel              *_serverModel;
    MUServerRootViewController *_serverRoot;
    UIViewController           *_parentViewController;
    UIAlertView                *_alertView;
    NSTimer                    *_timer;
    int                        _numDots;

    UIAlertView                *_rejectAlertView;
    MKRejectReason             _rejectReason;

    NSString                   *_hostname;
    NSUInteger                 _port;
    NSString                   *_username;
    NSString                   *_password;

    id                         _transitioningDelegate;
}
- (void) establishConnection;  //接続成立
- (void) teardownConnection;  //接続解除　＊あとでたくさん出てくる
- (void) showConnectingView;  //接続中の表示を出す
- (void) hideConnectingView;  //接続中の表示を隠す
@end

@implementation MUConnectionController

//クラスメソッド----------------------------------------
+ (MUConnectionController *) sharedController {
    static MUConnectionController *nc;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        // dispatch_once(&token は1度だけ実行するコード
        nc = [[MUConnectionController alloc] init];
    });
    return nc;
}

// スーパークラスへのメソッド--------------------------------------------------
- (id) init {
    if ((self = [super init])) {
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            _transitioningDelegate = [[MUHorizontalFlipTransitionDelegate alloc] init];
        }
    }
    return self;
}

// 割り当てたメモリの意図的な解放----------------------------------------------------
- (void) dealloc {
    [super dealloc];

    [_transitioningDelegate release];
}

// それぞれの情報をretainして、接続を実行する-----------------------------------------------------------------------
- (void) connetToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController {
    _hostname = [hostName retain];
    _port = port;
    _username = [userName retain];
    _password = [password retain];
    
    [self showConnectingView];
    [self establishConnection];  //接続成立
    
    _parentViewController = [parentViewController retain];
}
//---------------------------------------------------------------------------------------------------------

//接続したら
- (BOOL) isConnected {
    return _connection != nil;  //戻り値はnilじゃないを返す！
}

// サーバーから接続解除されたら
- (void) disconnectFromServer {
    [_serverRoot dismissModalViewControllerAnimated:YES];
    [self teardownConnection];  //teardownConnectionを実行する
}

//showConnectingViewの記述（表示内容や接続時間など）------------------------------------------------------------------
- (void) showConnectingView {
    NSString *title = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"無線機を立ち上げています", nil)];
    NSString *msg = [NSString stringWithFormat:
                        NSLocalizedString(@"Connecting to %@:%lu", @"Connecting to hostname:port"),  //まあここはいらないかな？
                            _hostname, (unsigned long)_port];
    
    // alertViewへ下記の記述を格納
    _alertView = [[UIAlertView alloc] initWithTitle:title
                                            message:msg
                                           delegate:self
                                  cancelButtonTitle:NSLocalizedString(@"キャンセル", nil)
                                  otherButtonTitles:nil];
    
// サーバー接続までの待機時間と接続するまで、表示をリピートさせるか？などの記述
    [_alertView show];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self selector:@selector(updateTitle) userInfo:nil repeats:YES];
}
//-----------------------------------------------------------------------------------------------------------------

//ConnectingViewが隠れる記述
- (void) hideConnectingView {
    [_alertView dismissWithClickedButtonIndex:1 animated:YES];  //キャンセルボタンを押したら
    [_alertView release];
    _alertView = nil;
    [_timer invalidate];
    _timer = nil;

    // This runloop wait works around a new behavior in iOS 7 where our UIAlertViews would suddenly
    // disappear if shown too soon after hiding the previous alert view.

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeInterval:0.350f sinceDate:[NSDate date]]];
    ////接続し、受信完了まで0.350fループを回す
}
//----------------------------------------------------------------------------------------------------------

// ここは接続出来たらどうするかという記述------------------------------------------------------------------------
- (void) establishConnection {
    _connection = [[MKConnection alloc] init];
    [_connection setDelegate:self];
    
    _serverModel = [[MKServerModel alloc] initWithConnection:_connection];
    [_serverModel addDelegate:self];
    
    _serverRoot = [[MUServerRootViewController alloc] initWithConnection:_connection andServerModel:_serverModel];
    
    // Set the connection's client cert if one is set in the app's preferences...
    //DefaultCertificateのところは設定いらない。ここは削除しても結構。
    NSData *certPersistentId = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    if (certPersistentId != nil) {
        NSArray *certChain = [MUCertificateChainBuilder buildChainFromPersistentRef:certPersistentId];
        [_connection setCertificateChain:certChain];
    }
    //-----------------------------------------------------------------------------
    
    [_connection connectToHost:_hostname port:_port];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MUConnectionOpenedNotification object:nil];
    });
}
//----------------------------------------------------------------------------------------------------------

// サーバー接続が解除されたら・・・の記載-----------------------------------------------------------
- (void) teardownConnection {
    [_serverModel removeDelegate:self];
    [_serverModel release];
    _serverModel = nil;
    [_connection setDelegate:nil];
    [_connection disconnect];
    [_connection release]; 
    _connection = nil;
    [_timer invalidate];
    [_serverRoot release];
    _serverRoot = nil;
    // 上記は様々な解放をしていっている
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MUConnectionClosedNotification object:nil];
    });
}
//-------------------------------------------------------------------------------------------

//サーバー接続中ですの表示のくだり------------------------------------------------------------------
- (void) updateTitle {
    ++_numDots;
    if (_numDots > 3)
        _numDots = 0;

    NSString *dots = @"   ";
    if (_numDots == 1) { dots = @".  "; }
    if (_numDots == 2) { dots = @".. "; }
    if (_numDots == 3) { dots = @"..."; }
    
    [_alertView setTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"接続中です", nil), dots]];
}
//----------------------------------------------------------------------------------------------

#pragma mark - MKConnectionDelegate

// 接続された後------------------------------------------------------------------------
- (void) connectionOpened:(MKConnection *)conn {
    NSArray *tokens = [MUDatabase accessTokensForServerWithHostname:[conn hostname] port:[conn port]];
    [conn authenticateWithUsername:_username password:_password accessTokens:tokens];
}
//------------------------------------------------------------------------------------

// 接続がエラーによって閉じる場合---------------------------------------------------
// ここでは接続している間に圏外になったりする場合のメッセージ

// 9/14更新
// 圏外になったら再接続を何度かループする設定が必要
// たぶん4Gから3Gに変更になっただけで接続が切れたはずなので、これはなんとかしないといけない

- (void) connection:(MKConnection *)conn closedWithError:(NSError *)err {
    [self hideConnectingView];
    if (err) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                            message:[err localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        [self teardownConnection];
    }
}

// ここからはどんな状況によって接続エラーになったのかを、状況別に引き出す記述-----------------------
- (void) connection:(MKConnection*)conn unableToConnectWithError:(NSError *)err {
    [self hideConnectingView];

    NSString *msg = [err localizedDescription];

    // errSSLClosedAbort: "connection closed via error".
    //
    // This is the error we get when users hit a global ban on the server.
    // Ideally, we'd provide better descriptions for more of these errors,
    // but when using NSStream's TLS support, the NSErrors we get are simply
    // OSStatus codes in an NSError wrapper without a useful description.
    //
    // In the future, MumbleKit should probably wrap the SecureTransport range of
    // OSStatus codes to improve this situation, but this will do for now.
    if ([[err domain] isEqualToString:NSOSStatusErrorDomain] && [err code] == -9806) {
        msg = NSLocalizedString(@"The TLS connection was closed due to an error.\n\n"
                                @"The server might be temporarily rejecting your connection because you have "
                                @"attempted to connect too many times in a row.", nil);
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unable to connect", nil)
                                                        message:msg
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    [self teardownConnection];
}
//-----------------------------------------------------------------------------------

// The connection encountered an invalid SSL certificate chain.
//SSL認証が合わない場合（使う予定はない）
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
    // Check the database whether the user trusts the leaf certificate of this server.
    NSString *storedDigest = [MUDatabase digestForServerWithHostname:[conn hostname] port:[conn port]];
    MKCertificate *cert = [[conn peerCertificates] objectAtIndex:0];
    NSString *serverDigest = [cert hexDigest];
    if (storedDigest) {
        if ([storedDigest isEqualToString:serverDigest]) {
            // Match
            [conn setIgnoreSSLVerification:YES];
            [conn reconnect];
            return;
        } else {
            // Mismatch.  The server is using a new certificate, different from the one it previously
            // presented to us.
            [self hideConnectingView];
            NSString *title = NSLocalizedString(@"Certificate Mismatch", nil);
            NSString *msg = NSLocalizedString(@"The server presented a different certificate than the one stored for this server", nil);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                            message:msg
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  otherButtonTitles:nil];
            [alert addButtonWithTitle:NSLocalizedString(@"Ignore", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Trust New Certificate", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Show Certificates", nil)];
            [alert show];
            [alert release];
        }
    } else {
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
        [self hideConnectingView];
        NSString *title = NSLocalizedString(@"Unable to validate server certificate", nil);
        NSString *msg = NSLocalizedString(@"Mumble was unable to validate the certificate chain of the server.", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              otherButtonTitles:nil];
        [alert addButtonWithTitle:NSLocalizedString(@"Ignore", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Trust Certificate", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Show Certificates", nil)];
        [alert show];
        [alert release];
    }
}
//---------------------------------------------------------------------------------------------------

// The server rejected our connection.
// 様々な理由により接続ができない場合の記述--------------------------------------------------------------------------------
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
    NSString *title = NSLocalizedString(@"Connection Rejected", nil);
    NSString *msg = nil;
    UIAlertView *alert = nil;
    
    [self hideConnectingView];
    [self teardownConnection];
    
    switch (reason) {
        case MKRejectReasonNone:
            msg = NSLocalizedString(@"No reason", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
        case MKRejectReasonWrongVersion:
            msg = @"Client/server version mismatch";
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];

            break;
        case MKRejectReasonInvalidUsername:
            msg = NSLocalizedString(@"Invalid username", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
            [[alert textFieldAtIndex:0] setText:_username];
            break;
        case MKRejectReasonWrongUserPassword:
            msg = NSLocalizedString(@"Wrong certificate or password for existing user", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStyleSecureTextInput];
            [[alert textFieldAtIndex:0] setText:_password];
            break;
        case MKRejectReasonWrongServerPassword:
            msg = NSLocalizedString(@"Wrong server password", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStyleSecureTextInput];
            [[alert textFieldAtIndex:0] setText:_password];
            break;
        case MKRejectReasonUsernameInUse:
            msg = NSLocalizedString(@"Username already in use", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
            [[alert textFieldAtIndex:0] setText:_username];
            break;
        case MKRejectReasonServerIsFull:
            msg = NSLocalizedString(@"Server is full", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
        case MKRejectReasonNoCertificate:
            msg = NSLocalizedString(@"A certificate is needed to connect to this server", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
    }

    _rejectAlertView = alert;
    _rejectReason = reason;

    [alert show];
    [alert release];
}
//-----------------------------------------------------------------------------------------

#pragma mark - MKServerModelDelegate

// サーバーにユーザーが入った時のサーバーモデルの状態
- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [MUDatabase storeUsername:[user userName] forServerWithHostname:[model hostname] port:[model port]];
    // データーベースにユーザー名が保存されるみたいな

    [self hideConnectingView];  //接続閉じるビューの表示

    [_serverRoot takeOwnershipOfConnectionDelegate];  //ここは謎

    //次々と解放
    [_username release];
    _username = nil;
    [_hostname release];
    _hostname = nil;
    [_password release];
    _password = nil;

    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            [_serverRoot setTransitioningDelegate:_transitioningDelegate];
        } else {
            [_serverRoot setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
        }
    }

    [_parentViewController presentModalViewController:_serverRoot animated:YES];
    [_parentViewController release];
    _parentViewController = nil;
}
//----------------------------------------------------------------------------------

#pragma mark - UIAlertView delegate

// あー、ここなんか初めて接続した際に出てくるアラートだと思う。ここは出てこないようにするか、
// もしくは自動的に無視するように設定したいところ。確かに初めて接続したらこのアラートがでて、前の画面に戻されたかと思う。
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    // Actions for the outermost UIAlertView
    if (alertView == _alertView) {
        if (buttonIndex == 0) {
            [self teardownConnection];
        } else if (buttonIndex == 1) {
            // ... nope.
        }
        return;
    }
    
    // Actions for the rejection UIAlertView
    if (alertView == _rejectAlertView) {
        if (_rejectReason == MKRejectReasonInvalidUsername || _rejectReason == MKRejectReasonUsernameInUse) {
            [_username release];
            UITextField *textField = [_rejectAlertView textFieldAtIndex:0];
            _username = [[textField text] copy];
        } else if (_rejectReason == MKRejectReasonWrongServerPassword || _rejectReason == MKRejectReasonWrongUserPassword) {
            [_password release];
            UITextField *textField = [_rejectAlertView textFieldAtIndex:0];
            _password = [[textField text] copy];
        }

        if (buttonIndex == 0) {
            // Rejection handler has already handled the teardown for us.
        } else if (buttonIndex == 1) {
            [self establishConnection];
            [self showConnectingView];
        }
        return;
    }
    
    // Actions that follow are for the certificate trust alert view
    
    // Cancel
    if (buttonIndex == 0) {
        // Tear down the connection.
        [self teardownConnection];
        
    // Ignore
    } else if (buttonIndex == 1) {
        // Ignore just reconnects to the server without
        // performing any verification on the certificate chain
        // the server presents us.
        [_connection setIgnoreSSLVerification:YES];
        [_connection reconnect];
        [self showConnectingView];
        
    // Trust
    } else if (buttonIndex == 2) {
        // Store the cert hash of the leaf certificate.  We then ignore certificate
        // verification errors from this host as long as it keeps on presenting us
        // the same certificate it always has.
        MKCertificate *cert = [[_connection peerCertificates] objectAtIndex:0];
        NSString *digest = [cert hexDigest];
        [MUDatabase storeDigest:digest forServerWithHostname:[_connection hostname] port:[_connection port]];
        [_connection setIgnoreSSLVerification:YES];
        [_connection reconnect];
        [self showConnectingView];
        
    // Show certificates
    } else if (buttonIndex == 3) {
        MUServerCertificateTrustViewController *certTrustView = [[MUServerCertificateTrustViewController alloc] initWithCertificates:[_connection peerCertificates]];
        [certTrustView setDelegate:self];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certTrustView];
        [certTrustView release];
        [_parentViewController presentModalViewController:navCtrl animated:YES];
        [navCtrl release];
    }
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    [self showConnectingView];
    [_connection reconnect];
}

@end
