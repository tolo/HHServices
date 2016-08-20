//
//  HHServiceDiscoveryOperation.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//


NS_ASSUME_NONNULL_BEGIN


/**
 * Base class for all DNS-SD API operation implementations in HHServices (i.e. browsing, publishing, resolving)
 */
@interface HHServiceDiscoveryOperation : NSObject

@property (nonatomic) int32_t lastError;
@property (nonatomic, readonly) BOOL hasFailed;

/** If you use HHServices in a different dispatch queue than the main dispatch queue, set this property to that queue. */
@property (nonatomic, weak, nullable) dispatch_queue_t mainDispatchQueue;

@end


#pragma mark - Utility categories

@interface NSDictionary (HHServices)

- (nullable NSData*) dataFromTXTRecordDictionary;

@end

@interface NSData (HHServices)

- (nullable NSDictionary*) dictionaryFromTXTRecordData;

@end


NS_ASSUME_NONNULL_END
