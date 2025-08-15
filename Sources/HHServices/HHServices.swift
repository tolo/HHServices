/// HHServices - Modern Swift DNS-SD Service Discovery Framework
///
/// A pure Swift implementation for DNS-SD (Bonjour) service discovery
/// with full support for Bluetooth P2P connectivity on iOS 11+.

// Re-export all public types
@_exported import Foundation
import dnssd

// Core types
public typealias HHService = Service
public typealias HHServiceBrowser = ServiceBrowser
public typealias HHServicePublisher = ServicePublisher
public typealias HHServiceResolver = ServiceResolver
public typealias HHServiceValidation = ServiceValidation
// HHServicesError is already the correct name, no alias needed
public typealias HHSocketAddress = SocketAddress
public typealias HHTXTRecord = TXTRecord

// Constants for special interface indices
public let kHHServiceInterfaceIndexAny: UInt32 = 0
public let kHHServiceInterfaceIndexLocalOnly: UInt32 = UInt32(bitPattern: -1)
public let kHHServiceInterfaceIndexUnicast: UInt32 = UInt32(bitPattern: -2)
public let kHHServiceInterfaceIndexP2P: UInt32 = UInt32(bitPattern: -3)
public let kHHServiceInterfaceIndexBLE: UInt32 = UInt32(bitPattern: -4)