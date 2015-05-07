// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// ログイン後の音声通信画面全般。ここが最も難関。
// 今後作りたい内容としては、小窓を用意します→音声入力中のユーザー名（２名くらいまで）が小窓に表示→入力終了したら、下に表示されている人が上にスライドしていくような感じのアニメーション

#import "MUServerViewController.h"
#import "MUNotificationController.h"
#import "MUColor.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"
#import "MUServerTableViewCell.h"
#import <MumbleKit/MKAudio.h>
@import CoreBluetooth;


#pragma mark -
#pragma mark MUChannelNavigationItem

//MUChannelNavigationItemクラスは多分外側の骨組みを設定しているだけ。インデントレベルの生成とか。あとは全部MUServerViewControllerクラスで記述
@interface MUChannelNavigationItem : NSObject {
    
    id         _object;
    
}

@end

@implementation MUChannelNavigationItem
+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj {
    
    return [[[MUChannelNavigationItem alloc] initWithObject:obj ] autorelease];
}

- (id) initWithObject:(id)obj {
    
    if (self = [super init]) {
        _object = obj;
    }
    
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (id) object {
    return _object;
}

@end

//ここまで-------------------------------------------------------

#pragma mark -
#pragma mark MUChannelNavigationViewController

@interface MUServerViewController () <CBCentralManagerDelegate, CBPeripheralDelegate> {
    
    MUServerViewControllerViewMode   _viewMode;
    MKServerModel                    *_serverModel;
    NSMutableArray                   *_modelItems;
    NSMutableDictionary              *_userIndexMap;
    NSMutableDictionary              *_channelIndexMap;
    BOOL                             _pttState;
    UIButton                         *_talkButton;
    UIButton                         *_searchButton;
    BOOL                              isScanning;

}

- (NSInteger) indexForUser:(MKUser *)user;  //通常のユーザー名
- (void) reloadUser:(MKUser *)user; //サーバーから読み込んだユーザー名
- (void) reloadChannel:(MKChannel *)channel;  //サーバーから読み込んだチャンネル
- (void) rebuildModelArrayFromChannel:(MKChannel *)channel;  //再構築したチャンネルモデル配列
- (void) addChannelTreeToModel:(MKChannel *)channel;  //addChannelTreeToModelがRootにぶら下がっている配列のこと

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@end


@implementation MUServerViewController

#pragma mark -
#pragma mark Initialization and lifecycle


// セルの表示をどのように設定するかという箇所------------------------------------------
- (id) initWithServerModel:(MKServerModel *)serverModel {
    
    if ((self = [super initWithStyle:UITableViewStylePlain])) {  //UITableViewStylePlainは通常のセルのスタイル
        
        _serverModel = [serverModel retain];
        [_serverModel addDelegate:self];
        _viewMode = MUServerViewControllerViewModeServer;
        
    }
    
    return self;
    
}

//解放
- (void) dealloc {
    
    [_serverModel removeDelegate:self];
    [_serverModel release];
    [super dealloc];
    
}

- (void) viewDidLoad {
    
    // セントラルマネージャー初期化
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];
}


//OSバージョン別の設定
- (void) viewWillAppear:(BOOL)animated {
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
        
    }
    
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorInset = UIEdgeInsetsZero;  //これをゼロに設定すると、端っこまで線が引かれる
        
    }
    
    if ([[MKAudio sharedAudio] transmitType] == MKTransmitTypeToggle) {
        
        //button
        UIImage *onImage = [UIImage imageNamed:@"talkbutton_on"];
        UIImage *offImage = [UIImage imageNamed:@"talkbutton_off"];
        
        // window
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        CGRect windowRect = [window frame];
        CGRect buttonRect = windowRect;
        buttonRect.size = onImage.size;
        buttonRect.origin.y = windowRect.size.height - (buttonRect.size.height + 40);
        buttonRect.origin.x = (windowRect.size.width - buttonRect.size.width)/2;
        
        // talkbuttonの状態変化
        _talkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _talkButton.frame = buttonRect;
        [_talkButton setBackgroundImage:onImage forState:UIControlStateHighlighted];  //押しっぱなしの状態
        [_talkButton setBackgroundImage:offImage forState:UIControlStateNormal]; //何もされていない状態
        [_talkButton setOpaque:NO];
        [_talkButton setAlpha:0.80f];
        [window addSubview:_talkButton];
        
        [_talkButton addTarget:self action:@selector(talkOn:) forControlEvents:UIControlEventTouchDown];  //PTTをタッチダウンされた時にtalkonメソッドを呼ぶようにする
        [_talkButton addTarget:self action:@selector(talkOff:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        
        
        // searchButtonの実装
        _searchButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
        _searchButton.frame = CGRectMake(100, 100, 100, 30);
        // ボタンがタッチダウンされた時にhogeメソッドを呼び出す
        [_searchButton addTarget:self action:@selector(search:) forControlEvents:UIControlEventTouchDown];
        [self.view addSubview:_searchButton];
        
        
        
        //PTTをタッチアップされた時にtalkoffメソッドを呼ぶようにする
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repositionTalkButton) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        //UIApplicationDidChangeStatusBarOrientationNotification→デバイスの向きが変わった後に通知
        [self repositionTalkButton];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];  //UIApplicationDidEnterBackgroundNotification→アプリケーションがバックグラウンドに入る時に通知
    }
}

//-----------------------------------------------------------------------------

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    

}


- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (_talkButton) {
        [_talkButton removeFromSuperview];
        _talkButton = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

// セルの配列の更新について---------------------------------------------------------------------
- (NSInteger) indexForUser:(MKUser *)user {
    NSNumber *number = [_userIndexMap objectForKey:[NSNumber numberWithInteger:[user session]]];
    
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (NSInteger) indexForChannel:(MKChannel *)channel {
    NSNumber *number = [_channelIndexMap objectForKey:[NSNumber numberWithInteger:[channel channelId]]]; //引数をnumberWithIntegerはNSNumberに変換して配列に格納
    
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (void) reloadUser:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:
         UITableViewRowAnimationRight];  //withRowAnimationは（引数の）アニメーションを使ってセクションを更新する。
    }
}

- (void) reloadChannel:(MKChannel *)channel {
    NSInteger idx = [self indexForChannel:channel];
    
    if (idx != NSNotFound) { //NSNotFoundは見つからない時につかうメソッド
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
    }
}
//--------------------------------------------------------------------------------------------


// チャンネルの解放-----------------------------------------------
- (void) rebuildModelArrayFromChannel:(MKChannel *)channel {
    [_modelItems release];
    _modelItems = [[NSMutableArray alloc] init];
    
    [_userIndexMap release];
    _userIndexMap = [[NSMutableDictionary alloc] init];

    [_channelIndexMap release];
    _channelIndexMap = [[NSMutableDictionary alloc] init];

    [self addChannelTreeToModel:channel];
}



//  チャンネルツリーにユーザーを追加されるときの記述----------------------------------------------
- (void) addChannelTreeToModel:(MKChannel *)channel{
    [_channelIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithInteger:[channel channelId]]];
    [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:channel ]];

    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
        [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:user ]];
    }
    for (MKChannel *chan in [channel channels]) {
        [self addChannelTreeToModel:chan ];
    }
}
//----------------------------------------------------------------------------------------------------------------


#pragma mark - Table view data source

// テーブルビューの個数は１つ
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;  //ここが２になると、表示される文字とアイコンが２つ表示されてしまう
}

//
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_modelItems count];
}

// ここはテーブルビューに何を表示させるのか
- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];
    if ([object class] == [MKChannel class]) {
        MKChannel *chan = object;
        if (chan == [_serverModel rootChannel] && [_serverModel serverCertificatesTrusted]) {
            cell.backgroundColor = [MUColor verifiedCertificateChainColor];
        }
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ChannelNavigationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            cell = [[[MUServerTableViewCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
        } else {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        }
    }

    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];

    MKUser *connectedUser = [_serverModel connectedUser];

    //通常のユーザーの文字の濃さの記述
    cell.textLabel.font = [UIFont systemFontOfSize:18];
    
    //Rootの表示の記述
    if ([object class] == [MKChannel class]) {
        MKChannel *chan = object;
        cell.imageView.image = [UIImage imageNamed:@"channel"]; //channelっていう画像はパラボラアンテナみたいなマーク
        cell.textLabel.text = [chan channelName];
        if (chan == [connectedUser channel])
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
    } else if ([object class] == [MKUser class]) {
        MKUser *user = object;
        
        //これは接続している自分の表示は濃い文字にしろっている記述
        cell.textLabel.text = [user userName];
        if (user == connectedUser)
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];

        //これは接続している自分の表示は濃い文字にしろっている記述
        cell.textLabel.text = [user userName];
        if (user == connectedUser)
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
        
        //タブのユーザーごとの唇画像のイメージを変える設定。唇マークが赤くなったり、グレイに戻ったり・・・
        MKTalkState talkState = [user talkState];
        NSString *talkImageName = nil;
        if (talkState == MKTalkStatePassive)
            talkImageName = @"talking_off";
        else if (talkState == MKTalkStateTalking)
            talkImageName = @"talking_on";
        
        
        // This check is here to correctly remove a user's talk state when backgrounding the app.
        //
        // For example, if the user of the app is holding his finger on the Push-to-Talk button
        // and decides to background Mumble while he is transmitting (via either the home- or
        // sleep button).
        //
        // This scenario brings two issues along with it:
        //
        //  1. We have to cut off Push-to-Talk when the app gets backgrounded - we get no TouchUpInside event
        //     from the UIButton, so we wouldn't regularly stop Push-to-Talk in this scenario.
        //
        //  2. Even if we set MKAudio's forceTransmit to NO, there exists a delay in the audio subsystem
        //     between setting the forceTransmit flag to NO before that change is propagated to MKServerModel
        //     delegates.
        //
        // The first problem is solved by registering a notification observer for when the app enters the
        // background. This is handled by the appDidEnterBackground: method of this class.
        //
        // This notification observer will set the forceTransmit flag to NO, but will also force-reload
        // the view controller's table view, causing us to enter this method soon before we're really backgrounded.
        //
        // That's fine, but because of problem #2, the user's talk state will most likely not be updated by the time
        // tableView:cellForRowAtIndexPath: is called by the table view.
        //
        // To solve this, we query the audio subsystem directly for the answer to whether the current user
        // should be treated as holding down Push-to-Talk, and therefore be listed with an active talk state
        // in the table view.
        if (user == connectedUser && [[MKAudio sharedAudio] transmitType] == MKTransmitTypeToggle) {
            if (![[MKAudio sharedAudio] forceTransmit]) {
                talkImageName = @"talking_off";
                // ユーザーが接続状態で、かつ、通信方法がPTTの場合で、もし、入力ON状態でなければトーキングOFFの画像表示する
            }
        }
        
        cell.imageView.image = [UIImage imageNamed:talkImageName];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        // ここではセルに何を表示されるのかという内容。ユーザー名とかPTTボタンとか
    }

    return cell;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];
    if ([object class] == [MKChannel class]) {
        [_serverModel joinChannel:object];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

#pragma mark - MKServerModel delegate

//serverModelっていうのがサーバービューモードの設定
- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    [self.tableView reloadData];
}

- (void) serverModel:(MKServerModel *)model userJoined:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userDisconnected:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userLeft:(MKUser *)user {
    NSInteger idx = [self indexForUser:user];
    if (idx != NSNotFound) {
        if (_viewMode == MUServerViewControllerViewModeServer) {
            [self rebuildModelArrayFromChannel:[model rootChannel]];
        } else if (_viewMode) {
        }
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
    }
}

//通話状態の変化を記述------------------------------------------------------------------------------------------
- (void) serverModel:(MKServerModel *)model userTalkStateChanged:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    if (userIndex == NSNotFound) {
        return;
    }

    UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];

    
    //タブ上に状態の変化のイメージを変える設定。唇マークが赤くなったり、グレイに戻ったり・・・
    MKTalkState talkState = [user talkState]; //通話状態の変化をどのようにするか
    NSString *talkImageName = nil;
    if (talkState == MKTalkStatePassive)
        talkImageName = @"talking_off";
    else if (talkState == MKTalkStateTalking)
        talkImageName = @"talking_on";

    cell.imageView.image = [UIImage imageNamed:talkImageName];
}

// チャンネル追加
- (void) serverModel:(MKServerModel *)model channelAdded:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        NSInteger idx = [self indexForChannel:channel];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
    }
}

//チャンネル削除
- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        [self.tableView reloadData];
    }
}

//チャンネル移動
- (void) serverModel:(MKServerModel *)model channelMoved:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        [self.tableView reloadData];
    }
}

//チャンネルリネーム
- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self reloadChannel:channel];
    }
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self.tableView beginUpdates];
        if (user == [model connectedUser]) {
            [self reloadChannel:chan];
            [self reloadChannel:prevChan];
        }
    
        // Check if the user is joining a channel for the first time.
        if (prevChan != nil) {
            NSInteger prevIdx = [self indexForUser:user];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:prevIdx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
        }

        [self rebuildModelArrayFromChannel:[model rootChannel]];
        NSInteger newIdx = [self indexForUser:user];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:newIdx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
        [self.tableView endUpdates];
    }
}

- (void) serverModel:(MKServerModel *)model userPrioritySpeakerChanged:(MKUser *)user {
    [self reloadUser:user];
}

#pragma mark - PushToTalk

// デバイスごとのPTTボタンのUI変更の記述---------------------------------------------------
- (void) repositionTalkButton {
    // fixme(mkrautz): This should stay put if we're run on the iPhone.
    return;
    
    UIDevice *device = [UIDevice currentDevice];
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    CGRect windowRect = window.frame;
    CGRect buttonRect;
    CGSize buttonSize;
    
    UIImage *onImage = [UIImage imageNamed:@"talkbutton_on"];
    buttonRect.size = onImage.size;
    buttonRect.origin = CGPointMake(0, 0);
    _talkButton.transform = CGAffineTransformIdentity;
    buttonSize = onImage.size;
    buttonRect.size = buttonSize;
    
    
    UIDeviceOrientation orientation = device.orientation;
    if (orientation == UIDeviceOrientationLandscapeLeft) {
        _talkButton.transform = CGAffineTransformMakeRotation(M_PI_2);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = (windowRect.size.height - buttonSize.width)/2;
        buttonRect.origin.x = 40;
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationLandscapeRight) {
        _talkButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = (windowRect.size.height - buttonSize.width)/2;
        buttonRect.origin.x = windowRect.size.width - (buttonSize.height + 40);
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationPortrait) {
        _talkButton.transform = CGAffineTransformMakeRotation(0.0f);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = windowRect.size.height - (buttonSize.height + 40);
        buttonRect.origin.x = (windowRect.size.width - buttonSize.width)/2;
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
        _talkButton.transform = CGAffineTransformMakeRotation(M_PI);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = 40;
        buttonRect.origin.x = (windowRect.size.width - buttonSize.width)/2;
        _talkButton.frame = buttonRect;
    }
}

- (void) talkOn:(UIButton *)button {
    [button setAlpha:1.0f];  //setAlphaは透明度の設定
    [[MKAudio sharedAudio] setForceTransmit:YES];   //たぶん音声入力がONの状態は「setForceTransmit」
}

- (void) talkOff:(UIButton *)button {
    [button setAlpha:0.80f];
    [[MKAudio sharedAudio] setForceTransmit:NO];
}
//--------------------------------------------------------------------------------

#pragma mark - Mode switch

// モードスイッチボタンを押した場合の設定（左上の小さいマンブルロゴ）-----------------------
- (void) toggleMode {}

#pragma mark - Background notification

// バックグラウンド状態の場合のsetForceTransmitの設定
- (void) appDidEnterBackground:(NSNotification *)notification {
    // Force Push-to-Talk to stop when the app is backgrounded.
    [[MKAudio sharedAudio] setForceTransmit:NO];
    
    // Reload the table view to re-render the talk state for the user
    // as not talking if they were holding down their Push-to-Talk buttons
    // at the moment the app was sent to the background.
    [[self tableView] reloadData];
}

// bluetoothの追加
// =============================================================================
#pragma mark - CBCentralManagerDelegate

// セントラルマネージャの状態が変化すると呼ばれる
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // 特に何もしない
    NSLog(@"centralManagerDidUpdateState:%ld", (long)central.state);
}

// ペリフェラルを発見すると呼ばれる
- (void)   centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)RSSI
{
    NSLog(@"発見したBLEデバイス：%@", peripheral);
    
    if ([peripheral.name hasPrefix:@"TI"]) {
        
        self.peripheral = peripheral;
        
        // 接続開始
        [self.centralManager connectPeripheral:peripheral
                                       options:nil];
    }
}

// 接続成功すると呼ばれる
- (void)  centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"接続成功！");
    
    peripheral.delegate = self;
    
    // サービス探索開始
    [peripheral discoverServices:nil];
}

// 接続失敗すると呼ばれる
- (void)        centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
    NSLog(@"接続失敗・・・");
}


// =============================================================================
#pragma mark - CBPeripheralDelegate

// サービス発見時に呼ばれる
- (void)     peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *services = peripheral.services;
    
    for (CBService *service in services) {
        
        // キャラクタリスティック探索開始
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// キャラクタリスティック発見時に呼ばれる
- (void)                      peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *characteristics = service.characteristics;
    
    for (CBCharacteristic *characteristic in characteristics) {
        
        // sensortagのsimplekeyのキャラクタリスティック
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFE1"]]) {
            
            // 更新通知受け取りを開始する
            [peripheral setNotifyValue:YES
                     forCharacteristic:characteristic];
        }
    }
}

// Notify開始／停止時に呼ばれる
- (void)                             peripheral:(CBPeripheral *)peripheral
    didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
                                          error:(NSError *)error
{
    if (error) {
        NSLog(@"Notify状態更新失敗...error:%@", error);
    }
    else {
        NSLog(@"Notify状態更新成功！characteristic UUID:%@, isNotifying:%d",
              characteristic.UUID ,characteristic.isNotifying ? YES : NO);
        
              // スキャン停止
              [self.centralManager stopScan];
        
        // アラートビュー
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"接続完了"
                                            message:@"Bluetoothデバイスが使用できます"
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// データ更新時に呼ばれる
- (void)                 peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error
{
    if (error) {
        NSLog(@"データ更新通知エラー:%@", error);
        return;
    }
    
    NSLog(@"データ更新！ characteristic UUID:%@, value:%@",
          characteristic.UUID, characteristic.value);
    
    /**
     Sensor Tag の場合 ボタンから
     * <00>
     * ボタンが離された
     * <01>
     * 右ボタンが押された
     * <02>
     * 左ボタンが押された
     のいずれかの NSData が返ってくる
     */
    
    UInt8 keyPress = 0;
    [characteristic.value getBytes:&keyPress length:1];
//    NSString *text = @"押されていない";
    NSLog(@"押されていない");
    [[MKAudio sharedAudio] setForceTransmit:NO];
    
    if (keyPress == 1) {
//        text = @"右";
        NSLog(@"右");
    } else if (keyPress == 2) {
//        text = @"左";
        NSLog(@"左");
        [[MKAudio sharedAudio] setForceTransmit:YES];
        
    } else if (keyPress == 3) {
//        text = @"両方";
        NSLog(@"両方");
    }
}


// bluetooth検索
- (void)cancelButtonPushed {}
- (void)otherButtonPushed {}

// searchメソッドの記述
-(void)search:(UIButton*) button {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"UIAlertControllerStyle.ActionSheet" message:@"Bluetoothに接続しますか?" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"接続" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // otherボタンが押された時の処理
        [self otherButtonPushed];
        
        isScanning = YES;
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
        
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // cancelボタンが押された時の処理
        [self cancelButtonPushed];
        
        //
        
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
}

@end

