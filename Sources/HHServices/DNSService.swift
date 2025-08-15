import Foundation
import dnssd

/// Low-level DNS-SD service wrapper providing Swift-friendly interface to the C API
internal final class DNSService {
    private var serviceRef: DNSServiceRef?
    private let queue: DispatchQueue
    private var source: DispatchSourceRead?
    
    init(queue: DispatchQueue = .global(qos: .default)) {
        self.queue = queue
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Service Management
    
    func stop() {
        source?.cancel()
        source = nil
        
        if let ref = serviceRef {
            DNSServiceRefDeallocate(ref)
            serviceRef = nil
        }
    }
    
    private func processResults() {
        guard let ref = serviceRef else { return }
        let result = DNSServiceProcessResult(ref)
        if result != kDNSServiceErr_NoError {
            stop()
        }
    }
    
    private func setupDispatchSource() throws {
        guard let ref = serviceRef else {
            throw HHServicesError.internalError
        }
        
        let socket = DNSServiceRefSockFD(ref)
        guard socket >= 0 else {
            throw HHServicesError.internalError
        }
        
        source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: queue)
        source?.setEventHandler { [weak self] in
            self?.processResults()
        }
        source?.resume()
    }
    
    // MARK: - Browse
    
    func browse(
        type: String,
        domain: String,
        interfaceIndex: UInt32,
        callback: @escaping (BrowseResult) -> Void
    ) throws {
        let context = BrowseContext(callback: callback)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        
        let result = DNSServiceBrowse(
            &serviceRef,
            0,
            interfaceIndex,
            type,
            domain.isEmpty ? nil : domain,
            { (_, flags, interfaceIndex, errorCode, serviceName, regtype, replyDomain, context) in
                guard let context = context else { return }
                let browseContext = Unmanaged<BrowseContext>.fromOpaque(context).takeUnretainedValue()
                
                if errorCode != kDNSServiceErr_NoError {
                    browseContext.callback(.failure(HHServicesError.dnsFailed(errorCode)))
                    return
                }
                
                let name = String(cString: serviceName!)
                let type = String(cString: regtype!)
                let domain = String(cString: replyDomain!)
                let isAdd = (flags & kDNSServiceFlagsAdd) != 0
                let moreComing = (flags & kDNSServiceFlagsMoreComing) != 0
                
                browseContext.callback(.success(BrowseEvent(
                    name: name,
                    type: type,
                    domain: domain,
                    interfaceIndex: interfaceIndex,
                    isAdd: isAdd,
                    moreComing: moreComing
                )))
            },
            contextPtr
        )
        
        guard result == kDNSServiceErr_NoError else {
            Unmanaged<BrowseContext>.fromOpaque(contextPtr).release()
            throw HHServicesError.dnsFailed(result)
        }
        
        try setupDispatchSource()
    }
    
    // MARK: - Resolve
    
    func resolve(
        name: String,
        type: String,
        domain: String,
        interfaceIndex: UInt32,
        includeP2P: Bool,
        callback: @escaping (ResolveResult) -> Void
    ) throws {
        let context = ResolveContext(callback: callback)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        
        let flags: DNSServiceFlags = includeP2P ? DNSServiceFlags(kDNSServiceFlagsIncludeP2P) : 0
        
        let result = DNSServiceResolve(
            &serviceRef,
            flags,
            interfaceIndex,
            name,
            type,
            domain,
            { (_, _, interfaceIndex, errorCode, _, hosttarget, port, txtLen, txtRecord, context) in
                guard let context = context else { return }
                let resolveContext = Unmanaged<ResolveContext>.fromOpaque(context).takeUnretainedValue()
                
                if errorCode != kDNSServiceErr_NoError {
                    resolveContext.callback(.failure(HHServicesError.dnsFailed(errorCode)))
                    return
                }
                
                let hostName = String(cString: hosttarget!)
                let portNumber = Int(bigEndianPort: port)
                
                var txtData: Data?
                if txtLen > 0, let txtRecord = txtRecord {
                    txtData = Data(bytes: txtRecord, count: Int(txtLen))
                }
                
                resolveContext.callback(.success(ResolveInfo(
                    hostName: hostName,
                    port: portNumber,
                    txtData: txtData,
                    interfaceIndex: interfaceIndex
                )))
            },
            contextPtr
        )
        
        guard result == kDNSServiceErr_NoError else {
            Unmanaged<ResolveContext>.fromOpaque(contextPtr).release()
            throw HHServicesError.dnsFailed(result)
        }
        
        try setupDispatchSource()
    }
    
    // MARK: - Get Address Info
    
    func getAddressInfo(
        hostName: String,
        interfaceIndex: UInt32,
        callback: @escaping (AddressResult) -> Void
    ) throws {
        let context = AddressContext(callback: callback)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        
        let result = DNSServiceGetAddrInfo(
            &serviceRef,
            0,
            interfaceIndex,
            DNSServiceProtocol(kDNSServiceProtocol_IPv4 | kDNSServiceProtocol_IPv6),
            hostName,
            { (_, flags, interfaceIndex, errorCode, hostname, address, _, context) in
                guard let context = context else { return }
                let addressContext = Unmanaged<AddressContext>.fromOpaque(context).takeUnretainedValue()
                
                if errorCode != kDNSServiceErr_NoError {
                    addressContext.callback(.failure(HHServicesError.dnsFailed(errorCode)))
                    return
                }
                
                guard let address = address else { return }
                
                let socketAddress = SocketAddress(sockaddr: address)
                let moreComing = (flags & kDNSServiceFlagsMoreComing) != 0
                
                addressContext.callback(.success(AddressInfo(
                    address: socketAddress,
                    interfaceIndex: interfaceIndex,
                    moreComing: moreComing
                )))
            },
            contextPtr
        )
        
        guard result == kDNSServiceErr_NoError else {
            Unmanaged<AddressContext>.fromOpaque(contextPtr).release()
            throw HHServicesError.dnsFailed(result)
        }
        
        try setupDispatchSource()
    }
    
    // MARK: - Register (Publish)
    
    func register(
        name: String,
        type: String,
        domain: String,
        port: UInt16,
        txtData: Data?,
        interfaceIndex: UInt32,
        callback: @escaping (RegisterResult) -> Void
    ) throws {
        let context = RegisterContext(callback: callback)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        
        let txtBytes = txtData?.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }
        let txtLen = UInt16(txtData?.count ?? 0)
        
        let result = DNSServiceRegister(
            &serviceRef,
            0,
            interfaceIndex,
            name.isEmpty ? nil : name,
            type,
            domain.isEmpty ? nil : domain,
            nil,
            port.bigEndian,
            txtLen,
            txtBytes,
            { (_, _, errorCode, name, regtype, domain, context) in
                guard let context = context else { return }
                let registerContext = Unmanaged<RegisterContext>.fromOpaque(context).takeUnretainedValue()
                
                if errorCode != kDNSServiceErr_NoError {
                    registerContext.callback(.failure(HHServicesError.dnsFailed(errorCode)))
                    return
                }
                
                let registeredName = String(cString: name!)
                let registeredType = String(cString: regtype!)
                let registeredDomain = String(cString: domain!)
                
                registerContext.callback(.success(RegisterInfo(
                    name: registeredName,
                    type: registeredType,
                    domain: registeredDomain
                )))
            },
            contextPtr
        )
        
        guard result == kDNSServiceErr_NoError else {
            Unmanaged<RegisterContext>.fromOpaque(contextPtr).release()
            throw HHServicesError.dnsFailed(result)
        }
        
        try setupDispatchSource()
    }
}

// MARK: - Context Classes

private class BrowseContext {
    let callback: (BrowseResult) -> Void
    init(callback: @escaping (BrowseResult) -> Void) {
        self.callback = callback
    }
}

private class ResolveContext {
    let callback: (ResolveResult) -> Void
    init(callback: @escaping (ResolveResult) -> Void) {
        self.callback = callback
    }
}

private class AddressContext {
    let callback: (AddressResult) -> Void
    init(callback: @escaping (AddressResult) -> Void) {
        self.callback = callback
    }
}

private class RegisterContext {
    let callback: (RegisterResult) -> Void
    init(callback: @escaping (RegisterResult) -> Void) {
        self.callback = callback
    }
}

// MARK: - Result Types

typealias BrowseResult = Result<BrowseEvent, Error>
typealias ResolveResult = Result<ResolveInfo, Error>
typealias AddressResult = Result<AddressInfo, Error>
typealias RegisterResult = Result<RegisterInfo, Error>

struct BrowseEvent {
    let name: String
    let type: String
    let domain: String
    let interfaceIndex: UInt32
    let isAdd: Bool
    let moreComing: Bool
}

struct ResolveInfo {
    let hostName: String
    let port: Int
    let txtData: Data?
    let interfaceIndex: UInt32
}

struct AddressInfo {
    let address: SocketAddress
    let interfaceIndex: UInt32
    let moreComing: Bool
}

struct RegisterInfo {
    let name: String
    let type: String
    let domain: String
}

// MARK: - Helpers

extension Int {
    init(bigEndianPort: UInt16) {
        self = Int(UInt16(bigEndian: bigEndianPort))
    }
}