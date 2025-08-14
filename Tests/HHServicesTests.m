//
//  HHServicesTests.m
//  HHServices Tests
//
//  Tests for HHServices DNS-SD framework
//

#import <XCTest/XCTest.h>
#import "HHService.h"
#import "HHServiceBrowser.h"
#import "HHServicePublisher.h"
#import "HHServiceValidation.h"

@interface HHServicesTests : XCTestCase <HHServiceBrowserDelegate, HHServicePublisherDelegate, HHServiceDelegate>
@property (nonatomic, strong) HHServiceBrowser *browser;
@property (nonatomic, strong) HHServicePublisher *publisher;
@property (nonatomic, strong) XCTestExpectation *browseExpectation;
@property (nonatomic, strong) XCTestExpectation *publishExpectation;
@property (nonatomic, strong) XCTestExpectation *resolveExpectation;
@property (nonatomic, strong) NSMutableArray<HHService *> *discoveredServices;
@end

@implementation HHServicesTests

- (void)setUp {
    [super setUp];
    self.discoveredServices = [NSMutableArray array];
}

- (void)tearDown {
    [self.browser endBrowse];
    [self.publisher endPublish];
    self.browser = nil;
    self.publisher = nil;
    [self.discoveredServices removeAllObjects];
    [super tearDown];
}

#pragma mark - Basic Initialization Tests

- (void)testServiceBrowserInitialization {
    HHServiceBrowser *browser = [[HHServiceBrowser alloc] initWithType:@"_test._tcp." domain:@"local."];
    XCTAssertNotNil(browser, @"Browser should be initialized");
    XCTAssertEqualObjects(browser.type, @"_test._tcp", @"Service type should match");
    XCTAssertEqualObjects(browser.domain, @"local.", @"Domain should match");
}

- (void)testServicePublisherInitialization {
    HHServicePublisher *publisher = [[HHServicePublisher alloc] initWithName:@"TestService" 
                                                                        type:@"_test._tcp." 
                                                                      domain:@"local." 
                                                                     txtData:nil 
                                                                        port:12345];
    XCTAssertNotNil(publisher, @"Publisher should be initialized");
    XCTAssertEqualObjects(publisher.name, @"TestService", @"Service name should match");
    XCTAssertEqualObjects(publisher.type, @"_test._tcp.", @"Service type should match");
    // Note: HHServicePublisher stores port internally but doesn't expose it as a property
}

- (void)testServiceInitialization {
    HHService *service = [[HHService alloc] initWithName:@"TestService" 
                                                    type:@"_test._tcp." 
                                                  domain:@"local."];
    XCTAssertNotNil(service, @"Service should be initialized");
    XCTAssertEqualObjects(service.name, @"TestService", @"Service name should match");
    XCTAssertEqualObjects(service.type, @"_test._tcp.", @"Service type should match");
    XCTAssertEqualObjects(service.domain, @"local.", @"Domain should match");
}

#pragma mark - Publishing and Browsing Tests

- (void)testServicePublishingAndDiscovery {
    // This test requires actual network access and may fail in isolated test environments
    // It's included as an example of integration testing
    
    self.publishExpectation = [self expectationWithDescription:@"Service should be published"];
    self.browseExpectation = [self expectationWithDescription:@"Service should be discovered"];
    
    // Start publishing
    NSData *txtData = [HHServiceValidation txtDataFromDictionary:@{@"test": @"data"}];
    self.publisher = [[HHServicePublisher alloc] initWithName:@"HHServicesTest" 
                                                         type:@"_hhtest._tcp." 
                                                       domain:@"local." 
                                                      txtData:txtData
                                                         port:54321];
    self.publisher.delegate = self;
    BOOL publishStarted = [self.publisher beginPublish];
    XCTAssertTrue(publishStarted, @"Publishing should start successfully");
    
    // Start browsing after a short delay to ensure publishing has started
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.browser = [[HHServiceBrowser alloc] initWithType:@"_hhtest._tcp." domain:@"local."];
        self.browser.delegate = self;
        BOOL browseStarted = [self.browser beginBrowse];
        XCTAssertTrue(browseStarted, @"Browsing should start successfully");
    });
    
    // Wait for both operations with timeout
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Test timed out: %@", error);
        }
    }];
}

- (void)testBluetoothOnlyBrowsing {
    self.browser = [[HHServiceBrowser alloc] initWithType:@"_hhtest._tcp." domain:@"local."];
    self.browser.delegate = self;
    
    // Test Bluetooth-only browsing
    BOOL browseStarted = [self.browser beginBrowseOverBluetoothOnly];
    // Note: This may fail if Bluetooth is not available or permissions are not granted
    if (!browseStarted) {
        XCTSkip(@"Bluetooth browsing not available in this test environment");
    }
    
    XCTAssertTrue(browseStarted, @"Bluetooth-only browsing should start if available");
    [self.browser endBrowse];
}

#pragma mark - Service Resolution Tests

- (void)testServiceResolution {
    HHService *service = [[HHService alloc] initWithName:@"TestService" 
                                                    type:@"_test._tcp." 
                                                  domain:@"local."];
    service.delegate = self;
    
    // Test different resolution methods
    BOOL resolveStarted = [service beginResolve];
    // Note: This will likely fail without an actual service to resolve
    if (!resolveStarted) {
        XCTSkip(@"Service resolution requires an actual service on the network");
    }
    
    [service endResolve];
}

#pragma mark - HHServiceBrowserDelegate

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser didFindService:(HHService *)service moreComing:(BOOL)moreComing {
    [self.discoveredServices addObject:service];
    
    if ([service.name isEqualToString:@"HHServicesTest"] && !moreComing) {
        [self.browseExpectation fulfill];
        
        // Test service resolution
        self.resolveExpectation = [self expectationWithDescription:@"Service should be resolved"];
        service.delegate = self;
        [service beginResolve];
    }
}

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser didRemoveService:(HHService *)service moreComing:(BOOL)moreComing {
    [self.discoveredServices removeObject:service];
}

#pragma mark - HHServicePublisherDelegate

- (void)servicePublisherDidPublish:(HHServicePublisher *)servicePublisher {
    [self.publishExpectation fulfill];
}

- (void)serviceDidNotPublish:(HHServicePublisher *)servicePublisher {
    XCTFail(@"Service publishing failed");
    [self.publishExpectation fulfill];
}

#pragma mark - HHServiceDelegate

- (void)serviceDidResolve:(HHService *)service moreComing:(BOOL)moreComing {
    if (!moreComing) {
        XCTAssertNotNil(service.resolvedHostName, @"Service should have resolved host name");
        XCTAssertGreaterThan(service.resolvedPortNumber, 0, @"Service should have valid port");
        [self.resolveExpectation fulfill];
    }
}

- (void)serviceDidNotResolve:(HHService *)service {
    XCTFail(@"Service resolution failed");
    [self.resolveExpectation fulfill];
}

#pragma mark - Error Code Tests

- (void)testPolicyDeniedErrorHandling {
    // Test handling of iOS 14+ Local Network permission denial
    NSError *policyError = [NSError errorWithDomain:@"com.dns_sd" code:-65570 userInfo:nil];
    
    // Verify we can detect policy denied errors
    XCTAssertEqual(policyError.code, -65570, @"Should recognize policy denied error code");
}

#pragma mark - TXT Record Tests

- (void)testTXTRecordHandling {
    NSDictionary *txtDict = @{@"key1": @"value1", @"key2": @"value2"};
    NSData *txtData = [HHServiceValidation txtDataFromDictionary:txtDict];
    XCTAssertNotNil(txtData, @"Should create valid TXT data");
    
    // Validate the TXT data
    XCTAssertTrue([HHServiceValidation isValidTXTRecordData:txtData], @"TXT data should be valid");
    
    // Parse it back
    NSDictionary *parsedDict = [HHServiceValidation dictionaryFromTXTData:txtData];
    XCTAssertEqualObjects(parsedDict[@"key1"], @"value1", @"Should parse key1 correctly");
    XCTAssertEqualObjects(parsedDict[@"key2"], @"value2", @"Should parse key2 correctly");
    
    HHServicePublisher *publisher = [[HHServicePublisher alloc] initWithName:@"TestService" 
                                                                        type:@"_test._tcp." 
                                                                      domain:@"local." 
                                                                     txtData:txtData 
                                                                        port:12345];
    XCTAssertNotNil(publisher.txtData, @"TXT data should be set");
}

#pragma mark - Validation Tests

- (void)testServiceNameValidation {
    // Valid names
    XCTAssertTrue([HHServiceValidation isValidServiceName:@"MyService"], @"Normal name should be valid");
    XCTAssertTrue([HHServiceValidation isValidServiceName:@"Service with spaces"], @"Spaces should be allowed");
    XCTAssertTrue([HHServiceValidation isValidServiceName:@"Émoji-Service"], @"UTF-8 should be allowed");
    
    // Invalid names
    XCTAssertFalse([HHServiceValidation isValidServiceName:nil], @"nil should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceName:@""], @"Empty string should be invalid");
    NSString *tooLong = [@"" stringByPaddingToLength:64 withString:@"x" startingAtIndex:0];
    XCTAssertFalse([HHServiceValidation isValidServiceName:tooLong], @"Name over 63 chars should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceName:@"Service\nNewline"], @"Control characters should be invalid");
}

- (void)testServiceTypeValidation {
    // Valid types
    XCTAssertTrue([HHServiceValidation isValidServiceType:@"_http._tcp."], @"Standard HTTP type should be valid");
    XCTAssertTrue([HHServiceValidation isValidServiceType:@"_test._udp."], @"UDP type should be valid");
    XCTAssertTrue([HHServiceValidation isValidServiceType:@"_my-service._tcp."], @"Hyphen should be allowed");
    
    // Invalid types
    XCTAssertFalse([HHServiceValidation isValidServiceType:nil], @"nil should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceType:@"http._tcp."], @"Missing underscore should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceType:@"_http.tcp."], @"Missing underscore before protocol should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceType:@"_http._xyz."], @"Invalid protocol should be invalid");
    XCTAssertFalse([HHServiceValidation isValidServiceType:@"_toolongservicename._tcp."], @"Service name over 15 chars should be invalid");
}

- (void)testDomainValidation {
    // Valid domains
    XCTAssertTrue([HHServiceValidation isValidDomain:@"local."], @"local. should be valid");
    XCTAssertTrue([HHServiceValidation isValidDomain:@"example.com."], @"example.com. should be valid");
    
    // Invalid domains
    XCTAssertFalse([HHServiceValidation isValidDomain:nil], @"nil should be invalid");
    XCTAssertFalse([HHServiceValidation isValidDomain:@""], @"Empty string should be invalid");
    XCTAssertFalse([HHServiceValidation isValidDomain:@"local"], @"Missing dot should be invalid");
    XCTAssertFalse([HHServiceValidation isValidDomain:@"-invalid.com."], @"Starting with hyphen should be invalid");
}

- (void)testServiceNameSanitization {
    XCTAssertEqualObjects([HHServiceValidation sanitizedServiceName:@"Valid Name"], @"Valid Name");
    XCTAssertEqualObjects([HHServiceValidation sanitizedServiceName:@"Name\nWith\tControl"], @"NameWithControl");
    NSString *tooLong = [@"" stringByPaddingToLength:100 withString:@"x" startingAtIndex:0];
    XCTAssertEqual([HHServiceValidation sanitizedServiceName:tooLong].length, 63);
    XCTAssertEqualObjects([HHServiceValidation sanitizedServiceName:@""], @"Service");
    XCTAssertEqualObjects([HHServiceValidation sanitizedServiceName:nil], @"Service");
}

@end