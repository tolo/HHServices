//
//  HHServiceValidation.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceValidation.h"

@implementation HHServiceValidation

+ (BOOL)isValidServiceName:(NSString *)name {
    if (!name || name.length == 0 || name.length > 63) {
        return NO;
    }
    
    // Check for valid UTF-8 and no control characters
    NSData *data = [name dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return NO;
    }
    
    // DNS-SD allows most UTF-8 characters in service names
    // but we should exclude obvious control characters
    NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
    NSRange range = [name rangeOfCharacterFromSet:controlChars];
    if (range.location != NSNotFound) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)isValidServiceType:(NSString *)type {
    if (!type || type.length < 7) { // Minimum: "_x._tcp."
        return NO;
    }
    
    // Must start with underscore
    if (![type hasPrefix:@"_"]) {
        return NO;
    }
    
    // Must end with either ._tcp. or ._udp.
    if (![type hasSuffix:@"._tcp."] && ![type hasSuffix:@"._udp."]) {
        return NO;
    }
    
    // Extract service name part
    NSString *serviceName = nil;
    if ([type hasSuffix:@"._tcp."]) {
        serviceName = [type substringWithRange:NSMakeRange(1, type.length - 7)];
    } else if ([type hasSuffix:@"._udp."]) {
        serviceName = [type substringWithRange:NSMakeRange(1, type.length - 7)];
    }
    
    // Service name must be 1-15 characters
    if (!serviceName || serviceName.length == 0 || serviceName.length > 15) {
        return NO;
    }
    
    // Service name must contain only alphanumeric and hyphen
    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    NSCharacterSet *invalidChars = [validChars invertedSet];
    NSRange range = [serviceName rangeOfCharacterFromSet:invalidChars];
    if (range.location != NSNotFound) {
        return NO;
    }
    
    // Cannot start or end with hyphen
    if ([serviceName hasPrefix:@"-"] || [serviceName hasSuffix:@"-"]) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)isValidDomain:(NSString *)domain {
    if (!domain || domain.length == 0 || domain.length > 253) {
        return NO;
    }
    
    // Most commonly "local." for mDNS
    if ([domain isEqualToString:@"local."]) {
        return YES;
    }
    
    // Basic domain validation
    // Must end with dot
    if (![domain hasSuffix:@"."]) {
        return NO;
    }
    
    // Split into labels
    NSString *domainWithoutDot = [domain substringToIndex:domain.length - 1];
    NSArray *labels = [domainWithoutDot componentsSeparatedByString:@"."];
    
    for (NSString *label in labels) {
        // Each label must be 1-63 characters
        if (label.length == 0 || label.length > 63) {
            return NO;
        }
        
        // Must contain only alphanumeric and hyphen
        NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
        NSCharacterSet *invalidChars = [validChars invertedSet];
        NSRange range = [label rangeOfCharacterFromSet:invalidChars];
        if (range.location != NSNotFound) {
            return NO;
        }
        
        // Cannot start or end with hyphen
        if ([label hasPrefix:@"-"] || [label hasSuffix:@"-"]) {
            return NO;
        }
    }
    
    return YES;
}

+ (BOOL)isValidTXTRecordData:(nullable NSData *)txtData {
    if (!txtData) {
        return YES; // nil is valid (no TXT record)
    }
    
    // Maximum total size for DNS TXT record
    if (txtData.length > 65535) {
        return NO;
    }
    
    // TXT records consist of length-prefixed strings
    const uint8_t *bytes = txtData.bytes;
    NSUInteger offset = 0;
    
    while (offset < txtData.length) {
        // Read length byte
        uint8_t length = bytes[offset];
        offset++;
        
        // Check if we have enough data for this string
        if (offset + length > txtData.length) {
            return NO; // Malformed: length exceeds available data
        }
        
        // Maximum individual string length is 255
        if (length > 255) {
            return NO;
        }
        
        // Validate the string content (should be key=value or just key)
        NSData *stringData = [NSData dataWithBytes:&bytes[offset] length:length];
        NSString *string = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
        
        if (!string) {
            return NO; // Not valid UTF-8
        }
        
        // Check for control characters that could cause issues
        NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
        NSRange range = [string rangeOfCharacterFromSet:controlChars];
        if (range.location != NSNotFound) {
            return NO;
        }
        
        offset += length;
    }
    
    return YES;
}

+ (NSString *)sanitizedServiceName:(NSString *)name {
    if (!name || name.length == 0) {
        return @"Service";
    }
    
    // Remove control characters
    NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
    NSString *sanitized = [[name componentsSeparatedByCharactersInSet:controlChars] componentsJoinedByString:@""];
    
    // Truncate to 63 characters
    if (sanitized.length > 63) {
        sanitized = [sanitized substringToIndex:63];
    }
    
    // Ensure it's not empty after sanitization
    if (sanitized.length == 0) {
        sanitized = @"Service";
    }
    
    return sanitized;
}

+ (nullable NSData *)txtDataFromDictionary:(NSDictionary<NSString *, NSString *> *)dictionary {
    if (!dictionary || dictionary.count == 0) {
        return [NSData data]; // Empty TXT record
    }
    
    NSMutableData *txtData = [NSMutableData data];
    
    for (NSString *key in dictionary) {
        NSString *value = dictionary[key];
        NSString *record = [NSString stringWithFormat:@"%@=%@", key, value];
        
        NSData *recordData = [record dataUsingEncoding:NSUTF8StringEncoding];
        if (!recordData || recordData.length > 255) {
            return nil; // Invalid record
        }
        
        // Add length byte
        uint8_t length = (uint8_t)recordData.length;
        [txtData appendBytes:&length length:1];
        [txtData appendData:recordData];
    }
    
    // Check total size
    if (txtData.length > 65535) {
        return nil;
    }
    
    return txtData;
}

+ (nullable NSDictionary<NSString *, NSString *> *)dictionaryFromTXTData:(NSData *)txtData {
    if (!txtData || txtData.length == 0) {
        return @{};
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    const uint8_t *bytes = txtData.bytes;
    NSUInteger offset = 0;
    
    while (offset < txtData.length) {
        // Read length byte
        uint8_t length = bytes[offset];
        offset++;
        
        // Check if we have enough data
        if (offset + length > txtData.length) {
            return nil; // Malformed data
        }
        
        // Extract string
        NSData *stringData = [NSData dataWithBytes:&bytes[offset] length:length];
        NSString *string = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
        
        if (!string) {
            return nil; // Invalid UTF-8
        }
        
        // Parse key=value
        NSRange equalRange = [string rangeOfString:@"="];
        if (equalRange.location != NSNotFound) {
            NSString *key = [string substringToIndex:equalRange.location];
            NSString *value = [string substringFromIndex:equalRange.location + 1];
            dictionary[key] = value;
        } else {
            // Just a key with no value
            dictionary[string] = @"";
        }
        
        offset += length;
    }
    
    return dictionary;
}

@end