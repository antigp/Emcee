import Foundation
import Logging
import Models

final class ArgumentsReader {
    private init() {}
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    public static func environment(file: String?, key: ArgumentDescription) throws -> [String: String] {
        return try decodeModelsFromFile(file, defaultValueIfFileIsMissing: [:], key: key)
    }
    
    public static func testDestinations(_ file: String?, key: ArgumentDescription) throws -> [TestDestinationConfiguration] {
        return try decodeModelsFromFile(file, key: key)
    }
    
    public static func deploymentDestinations(_ file: String?, key: ArgumentDescription) throws -> [DeploymentDestination] {
        return try decodeModelsFromFile(file, key: key)
    }
    
    public static func destinationConfigurations(_ file: String?, key: ArgumentDescription) throws -> [DestinationConfiguration] {
        return try decodeModelsFromFile(file, defaultValueIfFileIsMissing: [], key: key)
    }
    
    private static func decodeModelsFromFile<T>(_ file: String?, defaultValueIfFileIsMissing: T? = nil, key: ArgumentDescription) throws -> T where T: Decodable {
        if file == nil, let defaultValue = defaultValueIfFileIsMissing {
            return defaultValue
        }
        let path = try validateFileExists(file, key: key)
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try decoder.decode(T.self, from: data)
        } catch {
            log("Unable to read or decode file \(path): \(error)", color: .red)
            throw ArgumentsError.argumentValueCannotBeUsed(key, error)
        }
    }
    
    public static func scheduleStrategy(_ value: String?, key: ArgumentDescription) throws -> ScheduleStrategyType {
        let strategyRawType = try validateNotNil(value, key: key)
        guard let scheduleStrategy = ScheduleStrategyType(rawValue: strategyRawType) else {
            throw ArgumentsError.argumentValueCannotBeUsed(key, AdditionalArgumentValidationError.unknownScheduleStrategy(strategyRawType))
        }
        return scheduleStrategy
    }
    
    public static func queueServer(_ value: String?, key: ArgumentDescription) throws -> (host: String, port: Int) {
        let queueServer = try validateNotNil(value, key: key)
        let components = queueServer.components(separatedBy: ":")
        guard components.count == 2, let serverAddress = components.first, let serverPort = Int(components[1]) else {
            throw ArgumentsError.argumentValueCannotBeUsed(key, AdditionalArgumentValidationError.incorrectQueueServerFormat(queueServer))
        }
        return (host: serverAddress, port: serverPort)
    }
    
    public static func validateNotNil<T>(_ value: T?, key: ArgumentDescription) throws -> T {
        guard let value = value else { throw ArgumentsError.argumentIsMissing(key) }
        return value
    }
    
    public static func validateResourceLocation(_ value: String?, key: ArgumentDescription) throws -> ResourceLocation {
        let string = try validateNotNil(value, key: key)
        return try ResourceLocation.from(string)
    }
    
    public static func validateFileExists(_ value: String?, key: ArgumentDescription) throws -> String {
        let path = try validateNotNil(value, key: key)
        if !FileManager.default.fileExists(atPath: path) {
            throw ArgumentsError.argumentValueCannotBeUsed(key, AdditionalArgumentValidationError.notFound(path))
        }
        return path
    }
    
    public static func validateNilOrFileExists(_ value: String?, key: ArgumentDescription) throws -> String? {
        guard value != nil else { return nil }
        return try validateFileExists(value, key: key)
    }
    
    public static func validateFilesExist(_ values: [String], key: ArgumentDescription) throws -> [String] {
        return try values.map { try validateFileExists($0, key: key) }
    }
}
