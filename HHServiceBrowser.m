//
//  HHServiceBrowser.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceBrowser.h"

#import "HHServiceSupport+Private.h"

@interface HHServiceBrowser ()

// Redefinition of read only properties to readwrite
@property (nonatomic, retain, readwrite) NSString* type;
@property (nonatomic, retain, readwrite) NSString* domain;

@property (nonatomic, retain) HHService* resolver;

- (void) browserReceviedResult:(DNSServiceErrorType)error serviceName:(NSString*)serviceName serviceDomain:(NSString*)serviceDomain add:(BOOL)add moreComing:(BOOL)moreComing;

@end


#pragma mark -
#pragma mark Callbacks


static void browseCallBack(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, 
                           const char *serviceName, const char *regtype, const char *replyDomain, void *context) {
    HHServiceBrowser * serviceBrowser = (HHServiceBrowser *)context;
    
    BOOL add = flags & kDNSServiceFlagsAdd;
    BOOL moreComing = flags & kDNSServiceFlagsMoreComing;
    
    NSString* newName = [[NSString alloc] initWithCString:serviceName encoding:NSUTF8StringEncoding];
    NSString* newDomain = [[NSString alloc] initWithCString:replyDomain encoding:NSUTF8StringEncoding];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [serviceBrowser browserReceviedResult:errorCode serviceName:newName serviceDomain:newDomain add:add moreComing:moreComing];
        
        [newName release];
        [newDomain release];
    });
}


#pragma mark -
#pragma mark ServiceBrowser


@implementation HHServiceBrowser

@synthesize type, domain, includeP2P;
@synthesize delegate, resolver;


#pragma mark -
#pragma mark Internal methods


- (void) browserReceviedResult:(DNSServiceErrorType)error serviceName:(NSString*)serviceName serviceDomain:(NSString*)serviceDomain add:(BOOL)add moreComing:(BOOL)moreComing {
    self.lastError = error;
    if (error == kDNSServiceErr_NoError) {
        HHService* service = [[[HHService alloc] initWithName:serviceName type:self.type domain:serviceDomain includeP2P:self.includeP2P] autorelease];

        if( add ) [self.delegate serviceBrowser:self didFindService:service moreComing:moreComing];
        else [self.delegate serviceBrowser:self didRemoveService:service moreComing:moreComing];
    }
}


#pragma mark -
#pragma mark Creation and destruction


- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain {
    return [self initWithType:svcType domain:svcDomain includeP2P:YES];
}

- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)_includeP2P {
    if( (self = [super init]) ) {
        includeP2P = _includeP2P;
        
        if( [svcType hasSuffix:@"."] ) svcType = [svcType substringToIndex:svcType.length-1];
        
        self.type = svcType;
        self.domain = svcDomain;
    }
    return self;
}

- (void) dealloc {
    self.type = nil;
    self.domain = nil;
    
    self.resolver = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark ServicePublisher


- (BOOL) beginBrowse {
    const char* _type =  [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceFlags flags = 0;
#if TARGET_OS_IPHONE == 1
    flags = (uint32_t)(includeP2P ? kDNSServiceFlagsIncludeP2P : 0);
#endif

    DNSServiceRef browseRef = NULL;
    DNSServiceErrorType err = DNSServiceBrowse(&browseRef, flags, kDNSServiceInterfaceIndexAny, _type, _domain,
                                      browseCallBack, self);
    
    if( err == kDNSServiceErr_NoError ) {
        [self HHLogDebug:@"Beginning browse"];
        return [super setServiceRef:browseRef];
    } else {
        [self HHLogDebug:@"Error starting browse"];
        [self dnsServiceError:err];
        return NO;
    }
}

- (void) endBrowse {
    [self.resolver endResolve];
    self.resolver = nil;
    [super resetServiceRef];
}

- (HHService*) resolverForService:(NSString*)name {
    return [[[HHService alloc] initWithName:name type:self.type domain:self.domain includeP2P:self.includeP2P] autorelease];
}

- (BOOL) resolveService:(NSString*)name delegate:(id<HHServiceDelegate>)resolveDelegate {
    if( self.resolver ) [self.resolver endResolve];
    self.resolver = [self resolverForService:name];
    self.resolver.delegate = resolveDelegate;
    return [self.resolver beginResolve];
}


#pragma mark -
#pragma mark Equals & hashcode etc


- (NSString*) identityString {
    return [NSString stringWithFormat:@"%@|%@", self.type, self.domain];
}

- (NSUInteger)hash {
	return [self.identityString hash];
}

- (BOOL)isEqual:(id)anObject {
	return [anObject isKindOfClass:[self class]] && [self.identityString isEqual:((HHServiceBrowser *)anObject).identityString];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"HHServiceBrowser[%@, %@]", self.type, self.domain];
}


@end
