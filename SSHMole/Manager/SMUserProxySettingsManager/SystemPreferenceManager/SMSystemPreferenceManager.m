//
//  SMSystemPreferenceManager.m
//  SSHMole
//
//  Created by openthread on 6/8/15.
//  Copyright (c) 2015 openthread. All rights reserved.
//

#import "SMSystemPreferenceManager.h"
#import "SMCopyHelperWrapper.h"
#import "SMServerConfig.h"
#import "SMIPAddressHelper.h"

NSString *SMSystemPreferenceManagerOffProxyInfoKey = @"off";
NSString *SMSystemPreferenceManagerGlobalProxyInfoKey = @"global";
NSString *SMSystemPreferenceManagerAutoProxyInfoKey = @"auto";

@implementation SMSystemPreferenceManager
{
    SMServerConfig *_currentConfig;
    dispatch_queue_t _lockQueue;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _proxyMode = SMSystemProferenceManagerProxyModeGlobal;
        
        _lockQueue = dispatch_queue_create([[NSString stringWithFormat:@"SSHMole.SystemPreferenceManagerQueue.%@", self] UTF8String], NULL);

    }
    return self;
}

- (void)dealloc
{
    _lockQueue = nil;
}

- (void)setProxyMode:(SMSystemProferenceManagerProxyMode)proxyMode
{
    if (_proxyMode != proxyMode)
    {
        _proxyMode = proxyMode;
        [self updateProxySettings];
    }
}

- (void)updateCurrentProxySettingsForConfig:(SMServerConfig *)config
{
    if (_currentConfig != config)
    {
        _currentConfig = config;
        [self updateProxySettings];
    }
}

- (void)updateProxySettings
{
    NSDictionary *proxyInfo = @{};
    
    if (_currentConfig == nil)
    {
        [self runSystemConfigurationHelperWithMode:@"off" argument:nil];
        proxyInfo = @{};
    }
    else if (_proxyMode == SMSystemProferenceManagerProxyModeOff)
    {
        [self runSystemConfigurationHelperWithMode:@"off" argument:nil];
        
        NSString *localPortString = [NSString stringWithFormat:@"%zd", _currentConfig.localPort];
        NSString *globalProxyString = [NSString stringWithFormat:@"SOCKS %@:%@",
                                       [SMIPAddressHelper primaryNetworkIPAddressForURL],
                                       localPortString];
        proxyInfo = @{SMSystemPreferenceManagerOffProxyInfoKey: globalProxyString};
    }
    else if (_proxyMode == SMSystemProferenceManagerProxyModeGlobal)
    {
        NSString *localPortString = [NSString stringWithFormat:@"%zd", _currentConfig.localPort];
        [self runSystemConfigurationHelperWithMode:@"global" argument:localPortString];
        
        NSString *globalProxyString = [NSString stringWithFormat:@"SOCKS %@:%@",
                                       [SMIPAddressHelper primaryNetworkIPAddressForURL],
                                       localPortString];
        proxyInfo = @{SMSystemPreferenceManagerGlobalProxyInfoKey: globalProxyString};
    }
    else if (_proxyMode == SMSystemProferenceManagerProxyModeAutoWhitelist)
    {
        [self runSystemConfigurationHelperWithMode:@"auto" argument:self.whitelistPACURLString];
        
        NSString *localPortString = [NSString stringWithFormat:@"%zd", _currentConfig.localPort];
        NSString *globalProxyString = [NSString stringWithFormat:@"SOCKS %@:%@",
                                       [SMIPAddressHelper primaryNetworkIPAddressForURL],
                                       localPortString];
        proxyInfo = @{SMSystemPreferenceManagerGlobalProxyInfoKey: globalProxyString,
                      SMSystemPreferenceManagerAutoProxyInfoKey: self.whitelistPACURLString};
    }
    else if (_proxyMode == SMSystemProferenceManagerProxyModeAutoBlacklist)
    {
        [self runSystemConfigurationHelperWithMode:@"auto" argument:self.blacklistPACURLString];
        
        NSString *localPortString = [NSString stringWithFormat:@"%zd", _currentConfig.localPort];
        NSString *globalProxyString = [NSString stringWithFormat:@"SOCKS %@:%@",
                                       [SMIPAddressHelper primaryNetworkIPAddressForURL],
                                       localPortString];
        proxyInfo = @{SMSystemPreferenceManagerGlobalProxyInfoKey: globalProxyString,
                      SMSystemPreferenceManagerAutoProxyInfoKey: self.blacklistPACURLString};
    }
    
    [self.delegate systemPreferenceManager:self didUpdateProxyWithInfo:proxyInfo];
}

- (void)runSystemConfigurationHelperWithMode:(NSString *)mode argument:(NSString *)argument
{
    dispatch_sync(_lockQueue, ^{
        NSTask *task;
        task = [[NSTask alloc] init];
        [task setLaunchPath:[SMCopyHelperWrapper helperPath]];
        
        NSArray *arguments;
        arguments = [NSArray arrayWithObjects:mode, argument, nil];
        [task setArguments:arguments];
        
        NSPipe *stdoutpipe;
        stdoutpipe = [NSPipe pipe];
        [task setStandardOutput:stdoutpipe];
        
        NSPipe *stderrpipe;
        stderrpipe = [NSPipe pipe];
        [task setStandardError:stderrpipe];
        
        NSFileHandle *file;
        file = [stdoutpipe fileHandleForReading];
        
        [task launch];
        
        NSData *data;
        data = [file readDataToEndOfFile];
        
        NSString *string;
        string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (string.length > 0)
        {
            NSLog(@"SSHMole: change network settings result: %@", string);
        }
        
        file = [stderrpipe fileHandleForReading];
        data = [file readDataToEndOfFile];
        string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (string.length > 0)
        {
            NSLog(@"SSHMole: change network settings error: %@", string);
        }
    });
}

@end
