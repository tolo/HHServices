//
//  HHServiceDiscoveryOperation+Private.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//


typedef struct _DNSServiceRef_t *DNSServiceRef;


NS_ASSUME_NONNULL_BEGIN


@class HHServiceDiscoveryOperation;


@interface HHServiceDiscoveryOperationCallbackContext: NSObject

@property (atomic, weak) HHServiceDiscoveryOperation* operation;

@end


@interface HHServiceDiscoveryOperation ()

@property (nonatomic, nullable, readonly) DNSServiceRef serviceRef;

@property (nonatomic, nullable, readonly) dispatch_queue_t sdDispatchQueue;
@property (nonatomic, weak, readonly) dispatch_queue_t effectiveMainDispatchQueue;

@property (nonatomic, nullable, strong) HHServiceDiscoveryOperationCallbackContext* currentCallbackContext;

- (HHServiceDiscoveryOperationCallbackContext*) setCurrentCallbackContextWithSelf;

- (BOOL) setServiceRef:(DNSServiceRef)serviceRef;
- (void) resetServiceRef;

- (void) dnsServiceError:(int32_t)error;

- (void) HHLogDebug:(NSString*)format, ...;

@end


NS_ASSUME_NONNULL_END
