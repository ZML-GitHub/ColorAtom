//
//  GameKitHelper.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-9-12.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "GameKitHelper.h"
#import <EXTScope.h>
#import "AgainstPlayButton.h"
#import "GameConstants.h"

@interface GameKitHelper () <GKGameCenterControllerDelegate, GKMatchmakerViewControllerDelegate, GKMatchDelegate, GKLocalPlayerListener>

@property (nonatomic, assign, getter=isGameCenterFeaturesEnabled) BOOL gameCenterFeaturesEnabled;
@property (nonatomic, assign, getter=isMatchStarted) BOOL matchStarted;

@end

@implementation GameKitHelper

#pragma mark Singleton stuff

+ (instancetype)sharedGameKitHelper
{
    static GameKitHelper *sharedGameKitHelper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitHelper =
        [[GameKitHelper alloc] init];
    });
    return sharedGameKitHelper;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.achievementsDictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark Player Authentication

- (void)authenticateLocalPlayer
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    @weakify(localPlayer)
    localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
        @strongify(localPlayer)
        [self setLastError:error];
        if (localPlayer.authenticated) {
            self.gameCenterFeaturesEnabled = YES;
            [self loadAchievements];
            [localPlayer registerListener:self];
        } else if(viewController) {
            //TODO:palse
            [self presentViewController:viewController];
        } else {
            self.gameCenterFeaturesEnabled = NO;
        }
    };
}

#pragma mark Property setters

- (void)setLastError:(NSError*)error
{
    _lastError = [error copy];
    if (_lastError) {
//        NSLog(@"GameKitHelper ERROR: %@", [[_lastError userInfo]
//                                           description]);
    }
}

#pragma mark Achievements Methods
- (void)loadAchievements
{
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error)
     {
         if (error == nil)
         {
             for (GKAchievement* achievement in achievements)
                 self.achievementsDictionary[achievement.identifier] = achievement;
         }
     }];
}

- (GKAchievement*)getAchievementForIdentifier: (NSString*) identifier
{
    GKAchievement *achievement = self.achievementsDictionary[identifier];
    if (achievement == nil)
    {
        achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
        self.achievementsDictionary[achievement.identifier] = achievement;
    }
    return achievement;
}

- (void)updateAchievement:(GKAchievement*) achievement Identifier: (NSString*) identifier
{
    if (achievement)
    {
        (self.achievementsDictionary)[identifier] = achievement;
    }
}

- (void)reportMultipleAchievements
{
    
    [GKAchievement reportAchievements:(self.achievementsDictionary).allValues  withCompletionHandler:^(NSError *error)
     {
         if (error != nil)
         {
             NSLog(@"Error in reporting achievements: %@", error);
         }
     }];
}

- (void)showLeaderboard
{
    GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
    if (gameCenterController != nil)
    {
        gameCenterController.gameCenterDelegate = self;
        gameCenterController.viewState = GKGameCenterViewControllerStateAchievements;
        [self presentViewController: gameCenterController];
    }
}

#pragma mark UIViewController stuff

- (UIViewController*)getRootViewController
{
    return [UIApplication
            sharedApplication].keyWindow.rootViewController;
}

- (void)presentViewController:(UIViewController*)vc
{
    UIViewController* rootVC = self.rootViewController;
    [rootVC presentViewController:vc animated:YES
                       completion:nil];
}

#pragma mark CustomMethod

- (void)submitScore:(int64_t)score
           identifier:(NSString*)identifier
{
    //1: Check if Game Center
    //   features are enabled
    if (!_gameCenterFeaturesEnabled) {
        //@"Player not authenticated"
        return;
    }
    
    //2: Create a GKScore object
    GKScore* gkScore = [[GKScore alloc] initWithLeaderboardIdentifier:identifier];
    //3: Set the score value
    gkScore.value = score;
    
    //4: Send the score to Game Center
    [GKScore reportScores:@[gkScore] withCompletionHandler:
     ^(NSError* error) {
         
         [self setLastError:error];
         
         BOOL success = (error == nil);
         
         if ([self.delegate respondsToSelector:@selector(onScoresSubmitted:)]) { 
             [self.delegate onScoresSubmitted:success];
         }
     }];
}

- (BOOL)findMatchWithViewController:(UIViewController *)viewController
                       delegate:(id<GameKitHelperProtocol>)theDelegate
{
    
    if (!_gameCenterFeaturesEnabled) return NO;
    
    self.matchStarted = NO;
    self.match = nil;
    self.presentingViewController = viewController;
    self.delegate= theDelegate;
    [self.presentingViewController dismissViewControllerAnimated:NO completion:nil];

    
    if (self.pendingInvite) {
        GKMatchmakerViewController *mmvc =
        [[GKMatchmakerViewController alloc] initWithInvite:self.pendingInvite];
        mmvc.matchmakerDelegate = self;
        [self.presentingViewController presentViewController:mmvc animated:YES completion:nil];
        self.pendingInvite = nil;
        self.pendingPlayersToInvite = nil;
    }
    else {
        GKMatchRequest *request = [[GKMatchRequest alloc] init];
        request.minPlayers = 2;
        request.maxPlayers = 2;
        request.recipients = self.pendingPlayersToInvite;
        
        GKMatchmakerViewController *mmvc = [[GKMatchmakerViewController alloc] initWithMatchRequest:request];
        mmvc.matchmakerDelegate = self;
        [self.presentingViewController presentViewController:mmvc animated:YES completion:nil];
        self.pendingInvite = nil;
        self.pendingPlayersToInvite = nil;
    }
    return YES;
}

-(void)sendData:(NSData *)packet withCompleteBlock:(void(^)(void)) block{
    NSError *error;
    if (![[GameKitHelper sharedGameKitHelper].match sendDataToAllPlayers: packet withDataMode: GKMatchSendDataUnreliable error:&error]) {
        [self sendData:packet withCompleteBlock:block];
    }
    else{
        if (block!=nil) {
            block();
        }
    }
    if (error != nil)
    {
        // Handle the error.
    }
}

#pragma mark GKMatchmakerViewControllerDelegate

// The user has cancelled matchmaking
- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    [_presentingViewController dismissViewControllerAnimated:YES completion:^{

    }];
//    NSLog(@"Match was cancelled");
}

// Matchmaking has failed with an error
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    [_presentingViewController dismissViewControllerAnimated:YES completion:^{

    }];
//    NSLog(@"Error finding match: %@", error.localizedDescription);
}

// A peer-to-peer match has been found, the game should start
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)theMatch {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        [self.btn presentScene];
    }];
    self.match = theMatch;
    self.match.delegate= self;
    if (!self.matchStarted && _match.expectedPlayerCount ==0) {
        self.matchStarted = YES;
//        NSLog(@"Ready to start match!");
    }
}

#pragma mark GKMatchDelegate

// The match received data sent from the player.

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player
{
    Message *message = (Message *)data.bytes;
    if (message->messageType == kMessageTypeGameBeginRequest) {
        _opponentReady = YES;
        //        NSLog(@"receive beginrequest");
    }
    else if (message->messageType == kMessageTypeGameBeginResponse) {
        _opponentReady = YES;
        //        NSLog(@"receive beginresponse");
    }
    if ([self.delegate respondsToSelector:@selector(match:didReceiveData:fromRemotePlayer:)]) {
        [self.delegate match:match didReceiveData:data fromRemotePlayer:player];
    }
}

// The player state changed (eg. connected or disconnected)
- (void)match:(GKMatch *)match player:(GKPlayer *)player didChangeConnectionState:(GKPlayerConnectionState)state
{
    switch (state) {
        case GKPlayerStateConnected:
            // handle a new player connection.
            //            NSLog(@"Player connected!");
            
            if (!self.matchStarted && match.expectedPlayerCount == 0) {
                //                NSLog(@"Ready to start match!");
            }
            
            break;
        case GKPlayerStateDisconnected:
            // a player just disconnected.
            //            NSLog(@"Player disconnected!");
            self.matchStarted = NO;
            if ([self.delegate respondsToSelector:@selector(matchEnded)]) {
                [self.delegate matchEnded];
            }
            
            break;
        case GKPlayerStateUnknown:
            //            NSLog(@"state unknown");
            break;
    }
    if (!self.matchStarted && self.match.expectedPlayerCount == 0)
    {
        self.matchStarted = YES;
        // Handle initial match negotiation.
    }
}

// The match was unable to connect with the player due to an error.
- (void)match:(GKMatch *)theMatch connectionWithPlayerFailed:(NSString *)playerID withError:(NSError *)error {
    
    if (self.match != theMatch) return;
    
//    NSLog(@"Failed to connect to player with error: %@", error.localizedDescription);
    self.matchStarted = NO;
    if ([self.delegate respondsToSelector:@selector(matchEnded)]) {
        [self.delegate matchEnded];
    }
}

// The match was unable to be established with any players due to an error.
- (void)match:(GKMatch *)theMatch didFailWithError:(NSError *)error {
    
    if (self.match != theMatch) return;
    
//    NSLog(@"Match failed with error: %@", error.localizedDescription);
    self.matchStarted = NO;
    if ([self.delegate respondsToSelector:@selector(matchEnded)]) {
        [self.delegate matchEnded];
    }
}

#pragma mark GKGameCenterControllerDelegate
- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark GKInviteEventListener

- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite{
    self.pendingInvite = invite;
    if ([self.delegate respondsToSelector:@selector(inviteReceived)]) {
        [self.delegate inviteReceived];
    }
}

- (void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray *)recipientPlayers{
    self.pendingPlayersToInvite = recipientPlayers;
    if ([self.delegate respondsToSelector:@selector(inviteReceived)]) {
        [self.delegate inviteReceived];
    }
}
@end
