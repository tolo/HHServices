import Foundation

/// Utilities for validating service names, types, and domains according to DNS-SD specifications
public enum ServiceValidation {
    
    // MARK: - Service Name Validation
    
    /// Validates a service name according to DNS-SD specifications
    /// - Parameter name: The service name to validate
    /// - Returns: true if the name is valid, false otherwise
    public static func isValidServiceName(_ name: String) -> Bool {
        // Check basic requirements
        guard !name.isEmpty else { return false }
        
        // Convert to UTF-8 to check byte length
        guard let utf8Data = name.data(using: .utf8) else { return false }
        
        // DNS-SD spec: service names must be 1-63 bytes in UTF-8
        guard utf8Data.count >= 1 && utf8Data.count <= 63 else { return false }
        
        // Check for valid UTF-8 characters (no control characters)
        for scalar in name.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F {
                return false // Control characters not allowed
            }
        }
        
        return true
    }
    
    // MARK: - Service Type Validation
    
    /// Validates a service type according to DNS-SD specifications
    /// - Parameter type: The service type to validate (e.g., "_http._tcp.")
    /// - Returns: true if the type is valid, false otherwise
    public static func isValidServiceType(_ type: String) -> Bool {
        // Check basic format
        guard !type.isEmpty else { return false }
        
        // Service type should start with underscore
        guard type.hasPrefix("_") else { return false }
        
        // Should contain either _tcp or _udp
        let hasTCP = type.contains("._tcp")
        let hasUDP = type.contains("._udp")
        guard hasTCP || hasUDP else { return false }
        
        // Basic format check: _service._protocol.
        let pattern = "^_[a-zA-Z0-9]([a-zA-Z0-9-]{0,13}[a-zA-Z0-9])?\\.(_(tcp|udp))\\.?$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        
        let range = NSRange(location: 0, length: type.utf16.count)
        let matches = regex.matches(in: type, options: [], range: range)
        
        if !matches.isEmpty {
            return true
        }
        
        // Also check for subtypes: _service._protocol._subtype._sub._protocol.
        let subtypePattern = "^_[a-zA-Z0-9]([a-zA-Z0-9-]{0,13}[a-zA-Z0-9])?\\._(tcp|udp)(\\.[a-zA-Z0-9_-]+)*\\.?$"
        
        guard let subtypeRegex = try? NSRegularExpression(pattern: subtypePattern, options: .caseInsensitive) else {
            return false
        }
        
        let subtypeMatches = subtypeRegex.matches(in: type, options: [], range: range)
        return !subtypeMatches.isEmpty
    }
    
    // MARK: - Domain Validation
    
    /// Validates a domain according to DNS specifications
    /// - Parameter domain: The domain to validate (e.g., "local.")
    /// - Returns: true if the domain is valid, false otherwise
    public static func isValidDomain(_ domain: String) -> Bool {
        // Empty domain is valid (means default)
        if domain.isEmpty {
            return true
        }
        
        // Common valid domains
        if domain == "local." || domain == "local" {
            return true
        }
        
        // Check for double dots (invalid)
        if domain.contains("..") {
            return false
        }
        
        // Check for valid domain format
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        
        // Must have at least one non-empty label
        let nonEmptyLabels = labels.filter { !$0.isEmpty }
        if nonEmptyLabels.isEmpty {
            return false
        }
        
        // Check each label
        for label in labels {
            // Skip empty labels (like the one after trailing dot)
            if label.isEmpty {
                continue
            }
            
            // Label length must be 1-63 characters
            if label.count > 63 {
                return false
            }
            
            // Label must start with letter or digit
            guard let first = label.first else { continue }
            if !first.isLetter && !first.isNumber {
                return false
            }
            
            // Label must end with letter or digit
            if label.count > 1 {
                guard let last = label.last else { continue }
                if !last.isLetter && !last.isNumber {
                    return false
                }
            }
            
            // Label can contain letters, digits, and hyphens
            for char in label {
                if !char.isLetter && !char.isNumber && char != "-" {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Combined Validation
    
    /// Validates all components of a service
    /// - Parameters:
    ///   - name: The service name
    ///   - type: The service type
    ///   - domain: The domain
    /// - Returns: A validation result with any errors found
    public static func validateService(name: String, type: String, domain: String) -> ValidationResult {
        var errors: [ValidationError] = []
        
        if !isValidServiceName(name) {
            errors.append(.invalidServiceName(name))
        }
        
        if !isValidServiceType(type) {
            errors.append(.invalidServiceType(type))
        }
        
        if !isValidDomain(domain) {
            errors.append(.invalidDomain(domain))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Helper Types
    
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ValidationError]
    }
    
    public enum ValidationError: LocalizedError {
        case invalidServiceName(String)
        case invalidServiceType(String)
        case invalidDomain(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidServiceName(let name):
                return "Invalid service name: '\(name)'. Must be 1-63 bytes in UTF-8."
            case .invalidServiceType(let type):
                return "Invalid service type: '\(type)'. Must be in format '_service._tcp.' or '_service._udp.'"
            case .invalidDomain(let domain):
                return "Invalid domain: '\(domain)'"
            }
        }
    }
    
    // MARK: - Sanitization
    
    /// Sanitizes a service name to make it valid
    /// - Parameter name: The name to sanitize
    /// - Returns: A valid service name
    public static func sanitizeServiceName(_ name: String) -> String {
        var sanitized = name
        
        // Remove control characters
        sanitized = sanitized.unicodeScalars
            .filter { $0.value >= 0x20 && $0.value != 0x7F }
            .map { String($0) }
            .joined()
        
        // Truncate to 63 bytes
        while sanitized.data(using: .utf8)?.count ?? 0 > 63 {
            sanitized = String(sanitized.dropLast())
        }
        
        // If empty after sanitization, use a default
        if sanitized.isEmpty {
            sanitized = "Service"
        }
        
        return sanitized
    }
}