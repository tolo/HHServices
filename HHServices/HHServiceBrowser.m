//
//  HHServiceBrowser.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceBrowser.h"

#import "HHServiceDiscoveryOperation+Private.h"
#import <dns_sd.h>
#import <net/if.h>


@interface HHServiceBrowser ()

// Redefinition of read only properties to readwrite
@property (nonatomic, strong, readwrite) NSString* type;
@property (nonatomic, strong, readwrite) NSString* domain;

@property (nonatomic) uint32_t browseInterfaceIndex;
@property (nonatomic) BOOL browseIncludeP2P;

@property (nonatomic, strong) HHService* resolver;

- (void) browserReceviedResult:(DNSServiceErrorType)error interfaceIndex:(uint32_t)interfaceIndex serviceName:(NSString*)serviceName serviceDomain:(NSString*)serviceDomain add:(BOOL)add moreComing:(BOOL)moreComing;

@end


#pragma mark - Callbacks

static void browseCallBack(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, 
                           const char *serviceName, const char *regtype, const char *replyDomain, void *context) {
    
    HHServiceDiscoveryOperationCallbackContext* callbackContext = (__bridge HHServiceDiscoveryOperationCallbackContext*)context;
    HHServiceBrowser* serviceBrowser = (HHServiceBrowser*)callbackContext.operation;
    
    if( serviceBrowser ) {
        if( errorCode == kDNSServiceErr_NoError ) {
            BOOL add = flags & kDNSServiceFlagsAdd;
            BOOL moreComing = flags & kDNSServiceFlagsMoreComing;
            
            NSString* newName = serviceName ? [[NSString alloc] initWithCString:serviceName encoding:NSUTF8StringEncoding] : nil;
            NSString* newDomain = replyDomain ? [[NSString alloc] initWithCString:replyDomain encoding:NSUTF8StringEncoding] : nil;
            
            char interfaceName[IFNAMSIZ];
            if( if_indextoname(interfaceIndex, interfaceName) == NULL ) {
                interfaceIndex = kDNSServiceInterfaceIndexAny; // Only return actual (or kDNSServiceInterfaceIndexAny) interface indices
            }
            dispatch_async(serviceBrowser.effectiveMainDispatchQueue, ^{
                [serviceBrowser browserReceviedResult:errorCode interfaceIndex:interfaceIndex serviceName:newName serviceDomain:newDomain add:add moreComing:moreComing];
            });
        } else {
            [serviceBrowser dnsServiceError:errorCode];
        }
    }
}


#pragma mark - ServiceBrowser

@implementation HHServiceBrowser


#pragma mark - Internal methods

- (void) browserReceviedResult:(DNSServiceErrorType)error interfaceIndex:(uint32_t)interfaceIndex serviceName:(NSString*)serviceName serviceDomain:(NSString*)serviceDomain add:(BOOL)add moreComing:(BOOL)moreComing {
    self.lastError = error;
    if (error == kDNSServiceErr_NoError) {
        HHService* service = [[HHService alloc] initWithName:serviceName type:self.type domain:serviceDomain browsedInterfaceIndex:interfaceIndex];
#ifdef DEBUG
        char interfaceName[IFNAMSIZ];
        if( if_indextoname(interfaceIndex, interfaceName) != NULL ) {
            [service HHLogDebug:@"Service found by browser on interface index %d ('%s')", interfaceIndex, interfaceName];
        } else {
            [service HHLogDebug:@"Service found by browser on interface index %d", interfaceIndex];
        }
#endif

        if( add ) [self.delegate serviceBrowser:self didFindService:service moreComing:moreComing];
        else [self.delegate serviceBrowser:self didRemoveService:service moreComing:moreComing];
    }
}


#pragma mark - Creation and destruction

- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain {
    if( (self = [super init]) ) {
        if( [svcType hasSuffix:@"."] ) svcType = [svcType substringToIndex:svcType.length-1];
        
        _type = svcType;
        _domain = svcDomain;
    }
    return self;
}



#pragma mark - Browsing and resolving

- (BOOL) beginBrowse {
    return [self beginBrowse:kDNSServiceInterfaceIndexAny includeP2P:YES];
}

- (BOOL) beginBrowseOverBluetoothOnly {
    return [self beginBrowse:kDNSServiceInterfaceIndexP2P includeP2P:YES];
}

- (BOOL) beginBrowse:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P {
    if( self.serviceRef != nil ) {
        [self HHLogDebug:@"Browse operation already executing"];
        return NO;
    }
    
    self.browseInterfaceIndex = interfaceIndex;
    self.browseIncludeP2P = includeP2P;
    
    const char* type =  [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceRef browseRef = NULL;
    DNSServiceFlags flags = includeP2P ? kDNSServiceFlagsIncludeP2P : 0;
    DNSServiceErrorType err = DNSServiceBrowse(&browseRef, flags, interfaceIndex, type, domain,
                                               browseCallBack, (__bridge void *)([self setCurrentCallbackContextWithSelf]));
    
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
    return [[HHService alloc] initWithName:name type:self.type domain:self.domain];
}

- (BOOL) resolveService:(NSString*)name delegate:(id<HHServiceDelegate>)resolveDelegate {
    if( self.resolver ) [self.resolver endResolve];
    self.resolver = [self resolverForService:name];
    self.resolver.delegate = resolveDelegate;
    return [self.resolver beginResolve:self.browseInterfaceIndex includeP2P:self.browseIncludeP2P];
}


#pragma mark - Equals & hashcode etc

- (NSString*) identityString {
    return [NSString stringWithFormat:@"%@|%@", self.type, self.domain];
}

- (NSUInteger) hash {
	return [self.identityString hash];
}

- (BOOL) isEqual:(id)anObject {
	return [anObject isKindOfClass:[self class]] && [self.identityString isEqual:((HHServiceBrowser *)anObject).identityString];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"HHServiceBrowser[%@, %@]", self.type, self.domain];
}

@end
