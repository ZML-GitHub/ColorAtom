//
//  NightPlayButton.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-27.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "NightPlayButton.h"
#import "NightPlayScene.h"
#import "Define.h"

@implementation NightPlayButton
-(instancetype)init{
    if (self = [super init]) {
        self.fontName = FontString;
        self.fontSize = 30;
        self.text = NSLocalizedString(@"Night Mode", @"");
        self.userInteractionEnabled = YES;
    }
    return self;
}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
    SKScene * myScene = [[NightPlayScene alloc] initWithSize:self.scene.size];
    [self.scene.view presentScene:myScene transition: reveal];
}
@end
