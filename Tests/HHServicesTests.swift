import XCTest
@testable import HHServices

final class HHServicesTests: XCTestCase {
    
    // MARK: - Service Validation Tests
    
    func testServiceNameValidation() {
        // Valid names
        XCTAssertTrue(ServiceValidation.isValidServiceName("MyService"))
        XCTAssertTrue(ServiceValidation.isValidServiceName("Service-123"))
        XCTAssertTrue(ServiceValidation.isValidServiceName("A"))
        XCTAssertTrue(ServiceValidation.isValidServiceName("My Printer @ Home"))
        XCTAssertTrue(ServiceValidation.isValidServiceName("Service with émoji 🎉")) // Unicode is allowed
        
        // Invalid names
        XCTAssertFalse(ServiceValidation.isValidServiceName(""))
        XCTAssertFalse(ServiceValidation.isValidServiceName(String(repeating: "a", count: 100))) // Too long
        
        // Edge cases
        let exactly63Bytes = String(repeating: "a", count: 63)
        XCTAssertTrue(ServiceValidation.isValidServiceName(exactly63Bytes))
        
        let exactly64Bytes = String(repeating: "a", count: 64)
        XCTAssertFalse(ServiceValidation.isValidServiceName(exactly64Bytes))
    }
    
    func testServiceTypeValidation() {
        // Valid types
        XCTAssertTrue(ServiceValidation.isValidServiceType("_http._tcp."))
        XCTAssertTrue(ServiceValidation.isValidServiceType("_http._tcp"))
        XCTAssertTrue(ServiceValidation.isValidServiceType("_printer._tcp."))
        XCTAssertTrue(ServiceValidation.isValidServiceType("_test._udp."))
        XCTAssertTrue(ServiceValidation.isValidServiceType("_my-service._tcp."))
        
        // Invalid types
        XCTAssertFalse(ServiceValidation.isValidServiceType(""))
        XCTAssertFalse(ServiceValidation.isValidServiceType("http._tcp.")) // Missing leading underscore
        XCTAssertFalse(ServiceValidation.isValidServiceType("_http.tcp.")) // Missing underscore before tcp
        XCTAssertFalse(ServiceValidation.isValidServiceType("_http._xyz.")) // Invalid protocol
        XCTAssertFalse(ServiceValidation.isValidServiceType("_._tcp.")) // Empty service name
    }
    
    func testDomainValidation() {
        // Valid domains
        XCTAssertTrue(ServiceValidation.isValidDomain("local."))
        XCTAssertTrue(ServiceValidation.isValidDomain("local"))
        XCTAssertTrue(ServiceValidation.isValidDomain(""))  // Empty is valid (means default)
        XCTAssertTrue(ServiceValidation.isValidDomain("example.com."))
        XCTAssertTrue(ServiceValidation.isValidDomain("sub.example.com."))
        
        // Invalid domains
        XCTAssertFalse(ServiceValidation.isValidDomain("-invalid.com")) // Starts with hyphen
        XCTAssertFalse(ServiceValidation.isValidDomain("invalid-.com")) // Ends with hyphen
        XCTAssertFalse(ServiceValidation.isValidDomain("invalid..com")) // Double dot
        
        // Edge cases
        let longLabel = String(repeating: "a", count: 63)
        XCTAssertTrue(ServiceValidation.isValidDomain("\(longLabel).com"))
        
        let tooLongLabel = String(repeating: "a", count: 64)
        XCTAssertFalse(ServiceValidation.isValidDomain("\(tooLongLabel).com"))
    }
    
    func testServiceNameSanitization() {
        // Test control character removal
        let nameWithControl = "Service\u{0000}Name\u{007F}"
        XCTAssertEqual(ServiceValidation.sanitizeServiceName(nameWithControl), "ServiceName")
        
        // Test truncation
        let longName = String(repeating: "a", count: 100)
        let sanitized = ServiceValidation.sanitizeServiceName(longName)
        XCTAssertTrue(sanitized.data(using: .utf8)!.count <= 63)
        
        // Test empty becomes default
        XCTAssertEqual(ServiceValidation.sanitizeServiceName(""), "Service")
        XCTAssertEqual(ServiceValidation.sanitizeServiceName("\u{0000}"), "Service")
    }
    
    // MARK: - TXT Record Tests
    
    func testTXTRecordParsing() {
        // Create a TXT record with key-value pairs
        let dict = [
            "version": "1.0",
            "path": "/printer",
            "paper": "A4"
        ]
        
        let txtRecord = TXTRecord(dictionary: dict)
        
        // Test retrieval
        XCTAssertEqual(txtRecord["version"], "1.0")
        XCTAssertEqual(txtRecord["path"], "/printer")
        XCTAssertEqual(txtRecord["paper"], "A4")
        XCTAssertNil(txtRecord["nonexistent"])
        
        // Test keys
        XCTAssertTrue(txtRecord.hasKey("version"))
        XCTAssertFalse(txtRecord.hasKey("nonexistent"))
    }
    
    func testTXTRecordWithEmptyValues() {
        let dict = [
            "flag": "",
            "key": "value"
        ]
        
        let txtRecord = TXTRecord(dictionary: dict)
        XCTAssertEqual(txtRecord["flag"], "")
        XCTAssertEqual(txtRecord["key"], "value")
    }
    
    // MARK: - Socket Address Tests
    
    func testSocketAddressIPv4() {
        // Create IPv4 address data
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(8080).bigEndian
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        
        let data = Data(bytes: &addr, count: Int(addr.sin_len))
        let socketAddr = SocketAddress(data: data)
        
        XCTAssertEqual(socketAddr.family, .ipv4)
        XCTAssertEqual(socketAddr.port, 8080)
    }
    
    func testSocketAddressIPv6() {
        // Create IPv6 address data
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = UInt16(9090).bigEndian
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        
        let data = Data(bytes: &addr, count: Int(addr.sin6_len))
        let socketAddr = SocketAddress(data: data)
        
        XCTAssertEqual(socketAddr.family, .ipv6)
        XCTAssertEqual(socketAddr.port, 9090)
    }
    
    // MARK: - Service Tests
    
    func testServiceCreation() {
        let service = Service(
            name: "TestService",
            type: "_http._tcp.",
            domain: "local.",
            interfaceIndex: 0
        )
        
        XCTAssertEqual(service.name, "TestService")
        XCTAssertEqual(service.type, "_http._tcp.")
        XCTAssertEqual(service.domain, "local.")
        XCTAssertFalse(service.isResolved)
        XCTAssertFalse(service.hasAddresses)
    }
    
    func testServiceEquality() {
        let service1 = Service(name: "Test", type: "_http._tcp.", domain: "local.")
        let service2 = Service(name: "Test", type: "_http._tcp.", domain: "local.")
        let service3 = Service(name: "Other", type: "_http._tcp.", domain: "local.")
        
        XCTAssertEqual(service1, service2)
        XCTAssertNotEqual(service1, service3)
    }
    
    func testServiceResolution() {
        let service = Service(name: "Test", type: "_http._tcp.", domain: "local.")
        
        // Simulate resolution
        service.updateResolvedInfo(
            hostName: "test.local.",
            port: 8080,
            txtData: nil
        )
        
        XCTAssertTrue(service.isResolved)
        XCTAssertEqual(service.hostName, "test.local.")
        XCTAssertEqual(service.port, 8080)
    }
    
    // MARK: - Error Tests
    
    func testErrorDescriptions() {
        let error1 = HHServicesError.invalidServiceType
        XCTAssertNotNil(error1.errorDescription)
        
        let error2 = HHServicesError.localNetworkPermissionDenied
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertNotNil(error2.failureReason)
        
        let error3 = HHServicesError.dnsFailed(-65563)
        XCTAssertNotNil(error3.errorDescription)
    }
    
    // MARK: - Integration Tests
    
    func testServiceBrowserCreation() {
        let browser = ServiceBrowser(type: "_http._tcp.", domain: "local.")
        
        XCTAssertEqual(browser.serviceType, "_http._tcp.")
        XCTAssertEqual(browser.domain, "local.")
        XCTAssertEqual(browser.services.count, 0)
    }
    
    func testServicePublisherCreation() {
        let publisher = ServicePublisher(
            name: "TestService",
            type: "_http._tcp.",
            port: 8080
        )
        
        XCTAssertEqual(publisher.name, "TestService")
        XCTAssertEqual(publisher.type, "_http._tcp.")
        XCTAssertEqual(publisher.port, 8080)
    }
    
    func testInvalidServiceTypeThrows() {
        let browser = ServiceBrowser(type: "invalid", domain: "local.")
        
        XCTAssertThrowsError(try browser.startBrowsing()) { error in
            XCTAssertTrue(error is HHServicesError)
            if let hhError = error as? HHServicesError {
                XCTAssertEqual(hhError, HHServicesError.invalidServiceType)
            }
        }
    }
    
    func testInvalidDomainThrows() {
        let browser = ServiceBrowser(type: "_http._tcp.", domain: "-invalid")
        
        XCTAssertThrowsError(try browser.startBrowsing()) { error in
            XCTAssertTrue(error is HHServicesError)
            if let hhError = error as? HHServicesError {
                XCTAssertEqual(hhError, HHServicesError.invalidDomain)
            }
        }
    }
    
    // MARK: - Async Tests
    
    @available(iOS 13.0, *)
    func testAsyncBrowsingInterface() async throws {
        // Test that the async interface exists and compiles
        // We don't actually browse to avoid network dependencies in tests
        let browser = ServiceBrowser(type: "_test._tcp.", domain: "local.")
        
        // Just verify we can create the browser and it has the expected properties
        XCTAssertEqual(browser.serviceType, "_test._tcp.")
        XCTAssertEqual(browser.domain, "local.")
        XCTAssertEqual(browser.services.count, 0)
        
        // Verify stop doesn't crash
        browser.stop()
        
        // The test passes if the interface exists
        XCTAssertTrue(true)
    }
    
    @available(iOS 13.0, *)
    func testServiceResolverInterface() async throws {
        // Test that the resolver interface exists
        let service = Service(name: "Test", type: "_test._tcp.", domain: "local.")
        let resolver = ServiceResolver(service: service, timeout: 0.1)
        
        // Stop immediately to avoid network calls
        resolver.stop()
        
        // The test passes if we can create and stop the resolver
        XCTAssertTrue(true)
    }
}