import Foundation

public final class AbsolutePath: Path, Codable, Hashable {
    public let components: [String]
    
    public static let root = AbsolutePath(components: [])
    
    public static let userFolder = AbsolutePath(NSHomeDirectory())
    
    public init(components: [String]) {
        self.components = components
    }
    
    public var pathString: String {
        return "/" + components.joined(separator: "/")
    }
    
    public var fileUrl: URL {
        return URL(fileURLWithPath: pathString)
    }
    
    /// Finds a `RelativePath` for this instance and a given anchor path.
    public func relativePath(anchorPath: AbsolutePath) -> RelativePath {
        let pathComponents = components
        let anchorComponents = anchorPath.components
        
        var componentsInCommon = 0
        for (c1, c2) in zip(pathComponents, anchorComponents) {
            if c1 != c2 {
                break
            }
            componentsInCommon += 1
        }
        
        let numberOfParentComponents = anchorComponents.count - componentsInCommon
        let numberOfPathComponents = pathComponents.count - componentsInCommon
        
        var relativeComponents = [String]()
        relativeComponents.reserveCapacity(numberOfParentComponents + numberOfPathComponents)
        for _ in 0..<numberOfParentComponents {
            relativeComponents.append("..")
        }
        relativeComponents.append(contentsOf: pathComponents[componentsInCommon..<pathComponents.count])
        
        return RelativePath(components: relativeComponents)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self.components = StringPathParsing.components(path: stringValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(pathString)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(components)
    }
    
    public static func == (left: AbsolutePath, right: AbsolutePath) -> Bool {
        return left.components == right.components
    }
}
