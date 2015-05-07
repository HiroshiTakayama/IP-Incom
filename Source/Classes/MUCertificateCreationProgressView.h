// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// certificateのコードファイルは必要ないはず。任意で作成できるがなくても接続できる。
// いちおうボックスに入っている状態では、certificate（証明書）の内容は確認できるようにはなっている。
// たぶん自分で作成しなければランダムな暗号が出来上がっているはず。

@interface MUCertificateCreationProgressView : UIViewController
- (id) initWithName:(NSString *)name email:(NSString *)email;
- (void) dealloc;
@end