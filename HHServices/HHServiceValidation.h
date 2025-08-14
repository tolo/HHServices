//
//  HHServiceValidation.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Validation utilities for DNS-SD service parameters to prevent injection attacks
 * and ensure compliance with DNS-SD specifications.
 */
@interface HHServiceValidation : NSObject

/**
 * Validates a DNS-SD service name.
 * Service names must be 1-63 characters, UTF-8 encoded.
 * @param name The service name to validate
 * @return YES if valid, NO otherwise
 */
+ (BOOL)isValidServiceName:(NSString *)name;

/**
 * Validates a DNS-SD service type.
 * Must be in format "_service._protocol." where protocol is tcp or udp.
 * Service name must be 1-15 characters, alphanumeric and hyphen only.
 * @param type The service type to validate
 * @return YES if valid, NO otherwise
 */
+ (BOOL)isValidServiceType:(NSString *)type;

/**
 * Validates a DNS-SD domain.
 * Typically "local." for mDNS, but can be other valid domain names.
 * @param domain The domain to validate
 * @return YES if valid, NO otherwise
 */
+ (BOOL)isValidDomain:(NSString *)domain;

/**
 * Validates TXT record data for safety.
 * Ensures the data is properly formatted as key=value pairs.
 * Maximum total size is 65535 bytes, individual strings max 255 bytes.
 * @param txtData The TXT record data to validate
 * @return YES if valid, NO otherwise
 */
+ (BOOL)isValidTXTRecordData:(nullable NSData *)txtData;

/**
 * Sanitizes a service name to make it valid.
 * Truncates to 63 characters and removes invalid characters.
 * @param name The service name to sanitize
 * @return A sanitized version of the name
 */
+ (NSString *)sanitizedServiceName:(NSString *)name;

/**
 * Creates properly formatted TXT record data from a dictionary.
 * @param dictionary Dictionary with string keys and values
 * @return Properly formatted TXT record data, or nil if invalid
 */
+ (nullable NSData *)txtDataFromDictionary:(NSDictionary<NSString *, NSString *> *)dictionary;

/**
 * Parses TXT record data into a dictionary.
 * @param txtData The TXT record data to parse
 * @return Dictionary of key-value pairs, or nil if invalid
 */
+ (nullable NSDictionary<NSString *, NSString *> *)dictionaryFromTXTData:(NSData *)txtData;

@end

NS_ASSUME_NONNULL_END