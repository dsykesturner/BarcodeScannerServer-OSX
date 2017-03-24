//
//  ServerConnection.m
//  BarcodeScannerReceiver
//
//  Created by Daniel Sykes-Turner on 13/3/17.
//  Copyright © 2017 Universe Apps. All rights reserved.
//

#import "ServerConnection.h"
#import "Connection.h"

@implementation ServerConnection

- (id)init {
    self.clients = [[NSMutableSet alloc] init];
    
    return self;
}

// Start the server and announce self
- (BOOL)start {
    // Create new instance of the server and start it up
    self.server = [[Server alloc] init];
    
    // We will be processing server events
    self.server.delegate = self;
    
    // Try to start it up
    if (![self.server start]) {
        self.server = nil;
        return NO;
    }
    
    return YES;
}


// Stop everything
- (void)stop {
    // Destroy server
    [self.server stop];
    self.server = nil;
    
    // Close all connections
    [self.clients makeObjectsPerformSelector:@selector(close)];
}

#pragma mark - ServerDelegate

// Server has failed. Stop the world.
- (void) serverFailed:(Server*)server reason:(NSString*)reason {
    // Stop everything and let our delegate know
    [self stop];
//    [delegate roomTerminated:self reason:reason];
    NSLog(@"serverFailed");
}


// New client connected to our server. Add it.
- (void) handleNewConnection:(Connection*)connection {
    // Delegate everything to us
    connection.delegate = self;
    
    // Add to our list of clients
    [self.clients addObject:connection];
}

#pragma mark ConnectionDelegate

// We won't be initiating connections, so this is not important
- (void) connectionAttemptFailed:(Connection*)connection {
    NSLog(@"FAILED to make connection");
}


// One of the clients disconnected, remove it from our list
- (void) connectionTerminated:(Connection*)connection {
    [self.clients removeObject:connection];
    NSLog(@"Connection terminated");
}


// One of connected clients sent a chat message. Propagate it further.
- (void) receivedNetworkPacket:(NSDictionary*)packet viaConnection:(Connection*)connection {
    // Display message locally
    NSLog(@"receivedNetworkPacket: %@", packet);
//    [delegate displayChatMessage:[packet objectForKey:@"message"] fromUser:[packet objectForKey:@"from"]];
    
    [self.delegate serverConectionReceivedMessage:packet];
    
    // Broadcast this message to all connected clients, including the one that sent it
    [self.clients makeObjectsPerformSelector:@selector(sendNetworkPacket:) withObject:packet];
}

@end
