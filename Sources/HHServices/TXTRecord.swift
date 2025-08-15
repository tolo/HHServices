import Foundation

/// Represents a TXT record for a service
public struct TXTRecord: Sendable {
    public let data: Data
    internal let dictionaryData: [String: Data]
    
    public var dictionary: [String: String] {
        dictionaryData.compactMapValues { String(data: $0, encoding: .utf8) }
    }
    
    public init(data: Data) {
        self.data = data
        self.dictionaryData = TXTRecord.parse(data: data)
    }
    
    public init(dictionary: [String: String]) {
        self.dictionaryData = dictionary.mapValues { $0.data(using: .utf8) ?? Data() }
        self.data = TXTRecord.serialize(dictionary: self.dictionaryData)
    }
    
    /// Get a string value for a key
    public subscript(key: String) -> String? {
        guard let data = dictionaryData[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Get data value for a key
    public func data(for key: String) -> Data? {
        dictionaryData[key]
    }
    
    /// Get all keys
    public var keys: [String] {
        Array(dictionaryData.keys)
    }
    
    /// Check if a key exists
    public func hasKey(_ key: String) -> Bool {
        dictionaryData[key] != nil
    }
    
    // MARK: - Parsing
    
    private static func parse(data: Data) -> [String: Data] {
        var dict = [String: Data]()
        var index = 0
        
        while index < data.count {
            // Get the length of this entry
            let length = Int(data[index])
            index += 1
            
            guard index + length <= data.count else { break }
            
            // Extract the entry
            let entryData = data[index..<(index + length)]
            index += length
            
            // Parse key=value or just key
            if let equalIndex = entryData.firstIndex(of: UInt8(ascii: "=")) {
                let keyData = entryData[entryData.startIndex..<equalIndex]
                let valueData = entryData[(equalIndex + 1)..<entryData.endIndex]
                
                if let key = String(data: keyData, encoding: .utf8) {
                    dict[key] = Data(valueData)
                }
            } else {
                // No value, just a key
                if let key = String(data: entryData, encoding: .utf8) {
                    dict[key] = Data()
                }
            }
        }
        
        return dict
    }
    
    // MARK: - Serialization
    
    private static func serialize(dictionary: [String: Data]) -> Data {
        var data = Data()
        
        for (key, value) in dictionary {
            guard let keyData = key.data(using: .utf8) else { continue }
            
            let entry: Data
            if value.isEmpty {
                entry = keyData
            } else {
                entry = keyData + Data([UInt8(ascii: "=")]) + value
            }
            
            // Length byte followed by entry
            if entry.count <= 255 {
                data.append(UInt8(entry.count))
                data.append(entry)
            }
        }
        
        // Empty TXT record needs at least one zero byte
        if data.isEmpty {
            data.append(0)
        }
        
        return data
    }
}