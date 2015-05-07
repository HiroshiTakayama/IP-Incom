// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//ここはトップ画面の設定。UIを大幅に変更したいポイント。
// 9/10
// トップ画面に「接続」ボタンを配置して、そこを一度押せばラジオボックスに入る仕様に変更する

#import "MUWelcomeScreenPhone.h"

#import "MUFavouriteServerListController.h"
#import "MUServerRootViewController.h"
#import "MUNotificationController.h"
#import "MULegalViewController.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

// 追加してみた
@import CoreBluetooth;


@interface MUWelcomeScreenPhone () {
    UIAlertView  *_aboutView;
    NSInteger    _aboutWebsiteButton;
    NSInteger    _aboutContribButton;
    NSInteger    _aboutLegalButton;
}
@end

#define MUMBLE_LAUNCH_IMAGE_CREATION 0

// トップ画面のファイルの生成と解放など-------------------------------------------------------
@implementation MUWelcomeScreenPhone

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {   // グループ化されたスタイルを作成する
        // ...
    }
    return self;
}

- (void) dealloc {
    [super dealloc];  //割り当てたメモリの意図的な解放
}
//  ---------------------------------------------------------------------------------------


// トップ画面の設定----------------------------------------------------------------------------
- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];  //画面が表示される都度呼び出される -(void)viewWillAppear:(BOOL)animated
    
    self.navigationItem.title = @"Mumble";  //トップ画像の選択
    self.navigationController.toolbarHidden = YES;  //ツールバー（下部）を隠す設定
    
    // ナビゲーションバーをどのように設定するか
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    
    self.tableView.scrollEnabled = NO;  //テーブルビューをスクロールできるようにするかどうか
    
    // ---------------------------------------------------------------------------------------
    
#if MUMBLE_LAUNCH_IMAGE_CREATION != 1
    
    // ナビゲーションバーの左右上のボタン設定----------------------------------------------------
    UIBarButtonItem *about = [[UIBarButtonItem alloc] initWithTitle:@"その他"
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(aboutClicked:)];
    [self.navigationItem setRightBarButtonItem:about];
    [about release];
    
    
#endif
}
//  -----------------------------------------------------------------------------------------


// iPhoneが逆さまの時以外に画面回転のサポートをする--------------------------------------------------
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;  //// 通常
}

//---------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark TableView

// トップ画面の設定-------------------------------------------
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;  // ここで１以上の数字にすると、トップ画面が何個もできる
}

// Customize the number of rows in the table view.
// ここでは、テーブルビューのセルを何業作成するかという記述。リターン　数字　→で何個かえすかを設定する
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#if MUMBLE_LAUNCH_IMAGE_CREATION == 1
    return 1;
#endif
    if (section == 0)
        return 1;
    return 0;
}
//------------------------------------------------------------------------------------------

// このテーブルビューとトップ画像をどこに設置するかっている設定。ストーリーボードを使用する場合は必要ない-----
- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImage *img = [MUImage imageNamed:@"WelcomeScreenIcon"];
    UIImageView *imgView = [[[UIImageView alloc] initWithImage:img] autorelease];
    [imgView setContentMode:UIViewContentModeCenter];
    [imgView setFrame:CGRectMake(0, 0, img.size.width, img.size.height)];
    return imgView;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
#if MUMBLE_LAUNCH_IMAGE_CREATION == 1
    CGFloat statusBarAndTitleBarHeight = 64;
    return [UIScreen mainScreen].bounds.size.height - statusBarAndTitleBarHeight;
#endif
    UIImage *img = [MUImage imageNamed:@"WelcomeScreenIcon"];
    return img.size.height;
}

// セルの一行あたりの太さ
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

//-------------------------------------------------------------------------------------------


// Customize the appearance of table view cells.
// テーブルビューの表示をどうするかっている設定---------------------------------------------------------------

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"welcomeItem"];
    //dequeueReusableCellWithIdentifier:メソッドを使用して一度作成したセルを再利用
    
    if (!cell) {  //セルが作成されていなければ・・・。下記でセルを作成する
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"welcomeItem"] autorelease];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;  //分割する線はグレイにしてー
    
    /* Servers section. */
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"サーバー接続", nil);
        }
    }
    
    [[cell textLabel] setHidden: NO];
    
    return cell;
}

//------------------------------------------------------------------------------------------------

// Override to support row selection in the table view.
// さらにここでテーブルビューのサーバー表示をクリックしたと時にどのような動きをさせるかと設定する------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 「didSelectRowAtIndexPath」はセルがタップされた時にどのような動作をするか。それを下記に書く
    
    /* Servers section. */
    if (indexPath.section == 0) {
        
        if (indexPath.row == 0) {
            MUFavouriteServerListController *favList = [[[MUFavouriteServerListController alloc] init] autorelease];
            [self.navigationController pushViewController:favList animated:YES];
        }
    }
}

//------------------------------------------------------------------------------------------------------

// トップ画面右上のアバウトをクリックした際の動きの設定。アプリのバージョンを呼び出すメソッドなどは参考になる-------------------------
- (void) aboutClicked:(id)sender {
#ifdef MUMBLE_BETA_DIST
    NSString *aboutTitle = [NSString stringWithFormat:@"IP無線アプリ %@ (%@)",
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"]];
#else
    NSString *aboutTitle = [NSString stringWithFormat:@"IP無線アプリ %@",
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
#endif
    NSString *aboutMessage = NSLocalizedString(@"iPhone・iPadを業務用無線機に", nil);
    
    UIAlertView *aboutView = [[UIAlertView alloc] initWithTitle:aboutTitle message:aboutMessage delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"戻る", nil)
                                              otherButtonTitles:NSLocalizedString(@"公式ウェブサイト", nil),
                              NSLocalizedString(@"条項", nil),
                              NSLocalizedString(@"メール問い合わせフォーム", nil), nil];
    [aboutView show];
    [aboutView release];
}
// -----------------------------------------------------------------------------------------------------------


#pragma mark -
#pragma mark About Dialog

// alertViewについては本ファイルのトップで設定している。ここではアラートビューが出た後にどのような動きをさせるか------------
- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.yahoo.co.jp/"]];
    } else if (buttonIndex == 2) {
        MULegalViewController *legalView = [[MULegalViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] init];
        [navController pushViewController:legalView animated:NO];
        [legalView release];
        [[self navigationController] presentModalViewController:navController animated:YES];
        [navController release];
    } else if (buttonIndex == 3) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:info@radiobox.cc"]];
    }
}
// -----------------------------------------------------------------------------------------------------

@end