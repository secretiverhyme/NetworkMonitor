//
//  main.m
//  NetworkMonitor
//
//  Created by Nadine Salter on 24/10/2012.
//  Copyright (c) 2012 Nadine Salter. All rights reserved.
//
//  Quick-'n'-dirty wireless network state monitor.  Usage:
//      ./NetworkMonitor
//      [wait a while]
//      ^C
//

#include <time.h>
#include <signal.h>

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


static BOOL __wasConnected = NO;

static void signalHandler(const int sigid)
{
    CFRunLoopStop(CFRunLoopGetCurrent());
}

static void timestamp()
{
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"[HH:mm:ss]"];
    printf("%s\t", [[dateFormatter stringFromDate:date] UTF8String]);
}

static void notify(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    CFPropertyListRef result = SCDynamicStoreCopyValue(store, CFArrayGetValueAtIndex(changedKeys, 0));
    assert(CFGetTypeID(result) == CFDictionaryGetTypeID());
    
    const void *bssid = NULL;
    BOOL connected = CFDictionaryGetValueIfPresent(result, CFSTR("BSSID"), &bssid);
    
    if (info && CFEqual(info, CFSTR("INITIAL")))
        __wasConnected = !connected;
    
    if (connected && !__wasConnected) {
        /* nb:  CFStringGetCStringPtr() is not guaranteed to return a non-NULL value */
        CFStringRef ssidStr = CFDictionaryGetValue(result, CFSTR("SSID_STR"));
        const char *ssid = CFStringGetCStringPtr(ssidStr, CFStringGetFastestEncoding(ssidStr));
        
        SInt64 channel;
        CFNumberGetValue(CFDictionaryGetValue(result, CFSTR("CHANNEL")), kCFNumberSInt64Type, &channel);
        
        const UInt8 *macAddr = CFDataGetBytePtr(bssid);
        timestamp();
        printf("Associated with %s (%x:%x:%x:%x:%x:%x) on channel %lld.\n", ssid, *macAddr, *(macAddr+1), *(macAddr+2), *(macAddr+3), *(macAddr+4), *(macAddr+5), channel);
        
        __wasConnected = YES;
    }
    
    if (!connected && __wasConnected) {
        timestamp();
        printf("Disconnected.\n");
        __wasConnected = NO;
    }
    
    CFRelease(result);
}

int main(int argc, const char * argv[])
{
    SCDynamicStoreRef       _dynamicStore;
    CFRunLoopSourceRef      _dsRunLoop;
    CFArrayRef              _query;
    
    /* set up the SystemConfiguration dynamic store */
    _dynamicStore = SCDynamicStoreCreate(NULL, CFSTR("NetworkMonitor"), notify, NULL);
    
    /* listen for changes to the wireless adapter's state */
    CFStringRef key[] = { CFSTR("State:/Network/Interface/en0/AirPort") };
    _query = CFArrayCreate(NULL, (void *)key, 1, &kCFTypeArrayCallBacks);
    SCDynamicStoreSetNotificationKeys(_dynamicStore, _query, NULL);
    
    /* check current state */
    printf("Starting up NetworkMonitor...\n");
    notify(_dynamicStore, _query, (void *)CFSTR("INITIAL"));
    
    /* schedule on the current runloop */
    _dsRunLoop = SCDynamicStoreCreateRunLoopSource(NULL, _dynamicStore, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _dsRunLoop, kCFRunLoopCommonModes);
    
    /* go! */
    signal(SIGINT, (sig_t)signalHandler);
    CFRunLoopRun();
    
    /* cleanup */
    printf("\nShutting down...\n");
    CFRelease(_dynamicStore);
    CFRunLoopSourceInvalidate(_dsRunLoop);
    CFRelease(_dsRunLoop);
    CFRelease(_query);
    
    return 0;
}

