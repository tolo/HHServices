# HHServices Test Suite

This directory contains the comprehensive test suite for HHServices v3.0.

## Test Files

### HHServicesTests.swift
The original test file covering:
- Service validation (names, types, domains)
- TXT record parsing and handling
- Socket address (IPv4/IPv6) handling
- Service creation and equality
- Error descriptions
- Basic integration tests
- Async interface verification

### HHServicesComprehensiveTests.swift
Extended test coverage including:
- Complete ServicePublisher API testing
- Complete ServiceBrowser API testing
- ServiceResolver initialization and lifecycle
- Service hashing and collection support
- DiscoveryEvent properties
- TXT record edge cases (large values, special characters)
- Interface index constants
- Thread safety tests
- Memory management (deinit) tests
- Performance benchmarks
- Comprehensive async/await tests

### HHServicesMockTests.swift
Mock and integration tests covering:
- Delegate pattern implementation
- Weak reference verification
- Error simulation and handling
- Concurrent access patterns
- AsyncStream cancellation
- Edge cases (empty names, zero ports, special characters)
- Bluetooth P2P specific tests
- Notification handling
- Combine framework support

## Test Coverage Areas

### ✅ Fully Covered
- Service validation logic
- TXT record creation and parsing
- Socket address handling
- Service equality and hashing
- Error types and descriptions
- Thread safety
- Memory management
- API surface validation

### ⚠️ Limited Coverage (Network Dependent)
- Actual DNS-SD publishing
- Real network browsing
- Service resolution over network
- Bluetooth P2P connectivity

These require actual network access and would be integration tests rather than unit tests.

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test File
```bash
swift test --filter HHServicesComprehensiveTests
```

### Run with Coverage
```bash
swift test --enable-code-coverage
```

### Generate Coverage Report
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/HHServicesPackageTests.xctest/Contents/MacOS/HHServicesPackageTests -instr-profile .build/debug/codecov/default.profdata
```

## Test Guidelines

### Adding New Tests
1. Place unit tests in appropriate test class
2. Use descriptive test names starting with `test`
3. Include both positive and negative test cases
4. Test edge cases and error conditions
5. Add performance tests for critical paths

### Mock vs Real Tests
- Unit tests should not require network access
- Use mocks for DNS-SD operations
- Integration tests can be added separately for real network testing

### Async Testing
- Use `@available(iOS 13.0, *)` for async tests
- Properly cancel tasks and clean up
- Test both success and cancellation paths

## Known Limitations

1. **Network Operations**: Can't test actual DNS-SD without network access
2. **Bluetooth Testing**: Requires physical devices with Bluetooth
3. **Platform Specific**: Some tests may behave differently on iOS vs macOS

## Future Improvements

- [ ] Add integration test suite for real network operations
- [ ] Create performance baseline tests
- [ ] Add stress testing for concurrent operations
- [ ] Implement mock DNS-SD service for deeper testing
- [ ] Add UI testing for sample applications