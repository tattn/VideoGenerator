import Foundation

// Helper structs for encoding/decoding [String: Any]
struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        if let array = value as? [Any] {
            var container = encoder.unkeyedContainer()
            for item in array {
                try container.encode(AnyEncodable(item))
            }
        } else if let dictionary = value as? [String: Any] {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dictionary {
                try container.encode(AnyEncodable(value), forKey: DynamicCodingKey(stringValue: key))
            }
        } else if let string = value as? String {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        } else if let number = value as? NSNumber {
            // Handle NSNumber properly - check if it's actually a boolean
            // NSNumber can represent booleans, but we need to be careful with 0 and 1
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                var container = encoder.singleValueContainer()
                try container.encode(number.boolValue)
            } else if String(cString: number.objCType) == "c" {
                // This is actually a char/bool
                var container = encoder.singleValueContainer()
                try container.encode(number.boolValue)
            } else if number.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                // It's a whole number, encode as integer
                var container = encoder.singleValueContainer()
                try container.encode(number.intValue)
            } else {
                // It's a decimal number
                var container = encoder.singleValueContainer()
                try container.encode(number.doubleValue)
            }
        } else if let int = value as? Int {
            var container = encoder.singleValueContainer()
            try container.encode(int)
        } else if let double = value as? Double {
            var container = encoder.singleValueContainer()
            try container.encode(double)
        } else if let bool = value as? Bool {
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        } else if value is NSNull {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value of type \(type(of: value))"))
        }
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var result = [String: Any]()
            for key in container.allKeys {
                result[key.stringValue] = try container.decode(AnyDecodable.self, forKey: key).value
            }
            value = result
        } else if var container = try? decoder.unkeyedContainer() {
            var result = [Any]()
            while !container.isAtEnd {
                result.append(try container.decode(AnyDecodable.self).value)
            }
            value = result
        } else if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                value = NSNull()
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode value"))
        }
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}