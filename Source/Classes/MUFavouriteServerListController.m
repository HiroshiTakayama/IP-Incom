// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// ここは204行目のサーバー接続のコードが走ればOK。他の内容はまったくいらない。
// 接続コードの走らせ方を、ここではセル選択になっているが、ボタン選択で走るようにすればOK

#import "MUFavouriteServerListController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@interface MUFavouriteServerListController () <UIAlertViewDelegate> {
    NSMutableArray     *_favouriteServers;
    BOOL               _editMode;
    MUFavouriteServer  *_editedServer;
}
- (void) reloadFavourites;
- (void) deleteFavouriteAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation MUFavouriteServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super init])) {
        // ...
    }
    
    return self;
}

- (void) dealloc {
    [MUDatabase storeFavourites:_favouriteServers];
    [_favouriteServers release];
    
    [super dealloc];
}

// これはiPad版だけ画面を傾ける設定にしている箇所---------------------------------------------------------

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    // On iPad, we support all interface orientations.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return YES;
    }
    
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}
//---------------------------------------------------------------------------------------------------


// フェーバリットサーバーをタップしたあとに出てくる画面の設定。ここではナビゲーションコントローラの記述---------
- (void) viewWillAppear:(BOOL)animated {  //立ち上げる都度呼び出される画面の設定
    [super viewWillAppear:animated];

    [[self navigationItem] setTitle:NSLocalizedString(@"接続サーバー一覧", nil)];
    
    //ここでナビゲーションバーの文字色などを設定している
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    }
    
    //　ここは新たなサーバー接続先を追加する＋ボタンの設定箇所
    UIBarButtonItem *addButton =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];
    [addButton release];

    [self reloadFavourites];
}

- (void) reloadFavourites {
    [_favouriteServers release];
     _favouriteServers = [[MUDatabase fetchAllFavourites] retain];
    [_favouriteServers sortUsingSelector:@selector(compare:)];  //比較メソッドは2つのエレメントを比較するために使う
}
//----------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark Table view data source

// favouriteserverセルの全般的な記述-----------------------------------------------------------
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {  //ロード時に呼び出される。セクション数を返すように実装する
    return 1; //例えばこのリターン数を「２」にすると、自分でサーバー情報を登録すると、２つだぶった同じサーバー表示が出てしまう
}

//ロード時に呼び出される。セクションに含まれるセル数を返すように実装する
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_favouriteServers count];
}

//ロード時に呼び出される。セルの内容を返すように実装する
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    //使用可能なセルを取得
    MUServerCell *cell = (MUServerCell *)[tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {  //再利用できるセルがなければ
        cell = [[[MUServerCell alloc] init] autorelease]; //セル生成して、解放
    }
    [cell populateFromFavouriteServer:favServ];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;  //ここで設定したところで変化はないみたい
    return (UITableViewCell *) cell;
}

// 選択したセルが編集 (移動も含む) を許可する行だったら YES を返す
- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 上記メソッドは構文みたいなもので、編集モード時で、Delete、Insertされた時に呼び出される
    if (editingStyle == UITableViewCellEditingStyleDelete) {  //もし、削除されたら下記のメソッドを実行する
        [self deleteFavouriteAtIndexPath:indexPath];  //インデックスパスを削除するメソッドを実行
    }
}
//-------------------------------------------------------------------------------------------

//ちなみにパラぐまマークを書くと、ファンクションに一覧が出てくるよ
#pragma mark -
#pragma mark Table view delegate

// ここは登録しているセルの選択した場合、どのような動作を実行するかを記述。-------------------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    BOOL pad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    UIView *cellView = [[self tableView] cellForRowAtIndexPath:indexPath];  //ロード時に呼び出される。セルの内容を返すように実装する
    //ちなみにindexPathってひとつのセルのこと
    
    NSString *sheetTitle = pad ? nil : [favServ displayName];
    
    //サーバーを選択した時に出てくる項目。これは特にいらないし、設定画面でサーバー接続内容を設定すればもう出てこないようにしたい。
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"キャンセル", nil)
                                         destructiveButtonTitle:NSLocalizedString(@"削除", nil)
                                              otherButtonTitles:NSLocalizedString(@"編集", nil),
                                                                NSLocalizedString(@"無線を立ち上げる", nil), nil];
    
    // setActionSheetStyleとは選択画面のこと。ここでは選択画面の文字などの設定
    [sheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    if (pad) {
        CGRect frame = cellView.frame;
        frame.origin.y = frame.origin.y - (frame.size.height/2);
        [sheet showFromRect:frame inView:self.tableView animated:YES];
    } else {
        [sheet showInView:cellView];
    }
    [sheet release];
}
//------------------------------------------------------------------------------------------------------------------


// サーバー情報の削除の設定などなど。データーベースとローカルデータ（表示）の両方を消す必要あり------------------------------------
- (void) deleteFavouriteAtIndexPath:(NSIndexPath *)indexPath {  //deleteFavouriteAtIndexPathはインターフェイスで定義
    // データーベースに保存していた情報を引っ張りだして削除する
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    [MUDatabase deleteFavourite:favServ];
    
    // それで、セルに表示されている情報も消しちゃうよっていう記述
    [_favouriteServers removeObjectAtIndex:[indexPath row]];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}
//----------------------------------------------------------------------------------------------------------------


// アクションシート（接続とかエディットとか）のボタンを押した時の反応を記載している------------------------------------
- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    // ①Delete　削除のボタン-----------------------------------------------------------------------------
    if (index == 0) {
        NSString *title = NSLocalizedString(@"サーバー情報の削除", nil);
        NSString *msg = NSLocalizedString(@"サーバー情報を本当に削除してもよろしいですか？", nil);
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:msg
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"いいえ", nil)
                                                  otherButtonTitles:NSLocalizedString(@"はい", nil), nil];
        [alertView show];
        [alertView release];
        
        
    // ②Connect　接続のボタン-----------------------------------------------------------------------------
    } else if (index == 2) {
        NSString *userName = [favServ userName];
        if (userName == nil) {
            userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        }
        
        //ここでは、変数名「connCtrlr」へ格納を行い、それと解除メソッドの書いている
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:[favServ hostName]
                               port:[favServ port]
                            withUsername:userName
                        andPassword:[favServ password]
           withParentViewController:self];
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];  //もう一度同じセルが押されたら選択状況を解除するメソッド
        
        //----------------------------------------------------------------------------------------------
        
    // ③Edit　エディットが選択された場合
    } else if (index == 1) {
        [self presentEditDialogForFavourite:favServ];  //「presentEditDialogForFavourite」はヘッダーファイルで定義済み
        
    // ④Cancel　キャンセル
    } else if (index == 3) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
}
//--------------------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark UIAlertViewDelegate

// アラートが閉じた後に呼ばれるメソッド（たぶんここ書いてなかったら操作上バグりそう）--------------------------------------------------
- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex { //閉じた直後に呼ばれるメソッド
    NSIndexPath *selectedRow = [[self tableView] indexPathForSelectedRow];  //「selectedRow」にテーブルビューの選択している行を格納
    if (buttonIndex == 0) {
        // ...
    } else if (buttonIndex == 1) {
        [self deleteFavouriteAtIndexPath:selectedRow];
    }

    [[self tableView] deselectRowAtIndexPath:selectedRow animated:YES]; //選択状態の解除をします
}
//-------------------------------------------------------------------------------------------------------

#pragma mark -
#pragma Modal edit dialog

//サーバーの接続エディットを作成する画面の設定。まあスルーしても問題はないだろう---------------------------------------------------------------------
// ここの設定をいろいろいじっても、正常に動作するのでどういう項目なのか詳しくは不明
- (void) presentNewFavouriteDialog {
    UINavigationController *modalNav = [[UINavigationController alloc] init];  //UINavigationControllerクラスは、階層的な画面遷移を管理するクラスです
    
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] init];
    
    _editMode = NO;
    _editedServer = nil;
    
    [editView setTarget:self];
    [editView setDoneAction:@selector(doneButtonClicked:)];
    [modalNav pushViewController:editView animated:NO];
    [editView release];
    
    modalNav.modalPresentationStyle = UIModalPresentationFormSheet;  //iPadなどで全体画面ではなく、200x200などの小さい画面をmodalViewとして出したい時につかうメソッド
    [[self navigationController] presentModalViewController:modalNav animated:YES];
    [modalNav release];
}

- (void) presentEditDialogForFavourite:(MUFavouriteServer *)favServ {
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] initInEditMode:YES withContentOfFavouriteServer:favServ];
    // 基本的にストーリーボードで作成している場合は気にしなくて良い項目ばかりのはずなので、よくわからない記述が多い。
    
    _editMode = YES;
    _editedServer = favServ;
    
    [editView setTarget:self];
    [editView setDoneAction:@selector(doneButtonClicked:)];
    [modalNav pushViewController:editView animated:NO];
    [editView release];
    
    modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
    [[self navigationController] presentModalViewController:modalNav animated:YES];
    [modalNav release];
}
//----------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark Add button target

//
// Action for someone clicking the '+' button on the Favourite Server listing.-----------------------
//　＋ボタンが押されてからエディット画面を呼び出す記述。presentNewFavouriteDialogっていうのがエディット画面の名前

- (void) addButtonClicked:(id)sender {
    [self presentNewFavouriteDialog];
}
//---------------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark Done button target (from Edit View)

// Called when someone clicks 'Done' in a FavouriteServerEditViewController.-------------------------
// エディット画面で右上「Done」が押されたら、データーベースに保存→テーブルビューに表示っていう流れの記述
- (void) doneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = sender;
    MUFavouriteServer *newServer = [editView copyFavouriteFromContent];
    //copyFavouriteFromContentはサーバーエディットコントローラーのファイルで定義されている
    
    [MUDatabase storeFavourite:newServer];
    [newServer release];

    [self reloadFavourites];
    [self.tableView reloadData];
}
//-----------------------------------------------------------------------------------------------------

@end
