//
//  ServerConnection.h
//  BarcodeScannerReceiver
//
//  Created by Daniel Sykes-Turner on 13/3/17.
//  Copyright © 2017 Universe Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Server.h"
#import "ServerDelegate.h"
#import "ConnectionDelegate.h"

@protocol ServerConnectionDelegate

- (void) serverConectionReceivedMessage:(NSDictionary *)message;

@end

@interface ServerConnection : NSObject <ServerDelegate, ConnectionDelegate>

@property (nonatomic,retain) id<ServerConnectionDelegate> delegate;

// We accept connections from other clients using an instance of the Server class
@property (nonatomic, strong) Server* server;

// Container for all connected clients
@property (nonatomic, strong) NSMutableSet* clients;

- (id)init;
- (BOOL)start;
- (void)stop;

@end
