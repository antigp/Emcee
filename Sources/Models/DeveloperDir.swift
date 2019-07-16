import Foundation

public enum DeveloperDir: Codable, CustomStringConvertible, Hashable {
    case current
    case useXcode(CFBundleShortVersionString: String)
    
    private enum CodingKeys: CodingKey {
        case kind
        case CFBundleShortVersionString
    }
    
    private enum KindId: String, Codable {
        case current
        case useXcode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseId = try container.decode(KindId.self, forKey: .kind)
        switch caseId {
        case .current:
            self = .current
        case .useXcode:
            self = .useXcode(CFBundleShortVersionString: try container.decode(String.self, forKey: .CFBundleShortVersionString))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .current:
            try container.encode(KindId.current, forKey: .kind)
        case .useXcode(let CFBundleShortVersionString):
            try container.encode(KindId.useXcode, forKey: .kind)
            try container.encode(CFBundleShortVersionString, forKey: .CFBundleShortVersionString)
        }
    }
    
    public var description: String {
        switch self {
        case .current:
            return "current"
        case .useXcode(let CFBundleShortVersionString):
            return "Xcode \(CFBundleShortVersionString)"
        }
    }
}
