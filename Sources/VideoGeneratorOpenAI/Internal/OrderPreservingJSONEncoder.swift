import Foundation

// Custom JSONEncoder that preserves key order
final class OrderPreservingJSONEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = _OrderPreservingEncoder()
        try value.encode(to: encoder)
        guard let topLevel = encoder.storage.last else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }
        
        // Convert to JSON string manually to preserve order
        let jsonString = try convertToJSONString(topLevel)
        guard let data = jsonString.data(using: .utf8) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Failed to convert JSON string to data"))
        }
        return data
    }
    
    private func convertToJSONString(_ value: Any) throws -> String {
        if let dict = value as? NSMutableDictionary {
            var result = "{"
            var first = true
            for (key, val) in dict {
                if !first { result += "," }
                first = false
                result += "\"\(key)\":"
                result += try convertToJSONString(val)
            }
            result += "}"
            return result
        } else if let array = value as? NSMutableArray {
            var result = "["
            var first = true
            for val in array {
                if !first { result += "," }
                first = false
                result += try convertToJSONString(val)
            }
            result += "]"
            return result
        } else if let string = value as? String {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        } else if let number = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return number.boolValue ? "true" : "false"
            } else {
                return "\(number)"
            }
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if value is NSNull {
            return "null"
        } else {
            // Fallback to JSONSerialization for complex types
            let data = try JSONSerialization.data(withJSONObject: value)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}

private final class _OrderPreservingEncoder: Encoder {
    var storage: [Any] = []
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = OrderPreservingKeyedEncodingContainer<Key>(encoder: self)
        storage.append(container.storage)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: self)
        storage.append(container.storage)
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return OrderPreservingSingleValueEncodingContainer(encoder: self)
    }
}

private final class OrderPreservingKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let encoder: _OrderPreservingEncoder
    var storage: NSMutableDictionary = NSMutableDictionary()
    var codingPath: [CodingKey] { encoder.codingPath }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil(forKey key: Key) throws {
        storage[key.stringValue] = NSNull()
    }
    
    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        if let value = value as? String {
            storage[key.stringValue] = value
        } else if let value = value as? Int {
            storage[key.stringValue] = value
        } else if let value = value as? Double {
            storage[key.stringValue] = value
        } else if let value = value as? Bool {
            storage[key.stringValue] = value
        } else if value is NSNull {
            storage[key.stringValue] = NSNull()
        } else {
            let subEncoder = _OrderPreservingEncoder()
            subEncoder.codingPath = encoder.codingPath
            try value.encode(to: subEncoder)
            if let encoded = subEncoder.storage.last {
                storage[key.stringValue] = encoded
            }
        }
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        let container = OrderPreservingKeyedEncodingContainer<NestedKey>(encoder: encoder)
        storage[key.stringValue] = container.storage
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: encoder)
        storage[key.stringValue] = container.storage
        return container
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }
}

private final class OrderPreservingUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _OrderPreservingEncoder
    var storage: NSMutableArray = NSMutableArray()
    var codingPath: [CodingKey] { encoder.codingPath }
    var count: Int { storage.count }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil() throws {
        storage.add(NSNull())
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        if let value = value as? String {
            storage.add(value)
        } else if let value = value as? Int {
            storage.add(value)
        } else if let value = value as? Double {
            storage.add(value)
        } else if let value = value as? Bool {
            storage.add(value)
        } else if value is NSNull {
            storage.add(NSNull())
        } else {
            let subEncoder = _OrderPreservingEncoder()
            subEncoder.codingPath = encoder.codingPath
            try value.encode(to: subEncoder)
            if let encoded = subEncoder.storage.last {
                storage.add(encoded)
            }
        }
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let container = OrderPreservingKeyedEncodingContainer<NestedKey>(encoder: encoder)
        storage.add(container.storage)
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: encoder)
        storage.add(container.storage)
        return container
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
}

private final class OrderPreservingSingleValueEncodingContainer: SingleValueEncodingContainer {
    private let encoder: _OrderPreservingEncoder
    var codingPath: [CodingKey] { encoder.codingPath }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil() throws {
        encoder.storage.append(NSNull())
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        if let value = value as? String {
            encoder.storage.append(value)
        } else if let value = value as? Int {
            encoder.storage.append(value)
        } else if let value = value as? Double {
            encoder.storage.append(value)
        } else if let value = value as? Bool {
            encoder.storage.append(value)
        } else if value is NSNull {
            encoder.storage.append(NSNull())
        } else {
            try value.encode(to: encoder)
        }
    }
}