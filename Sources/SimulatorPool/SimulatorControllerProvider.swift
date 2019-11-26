import DeveloperDirLocator
import Foundation
import Models

public protocol SimulatorControllerProvider {
    func createSimulatorController(
        developerDir: DeveloperDir,
        developerDirLocator: DeveloperDirLocator,
        simulatorControlTool: SimulatorControlTool,
        simulatorSettings: SimulatorSettings,
        testDestination: TestDestination
    ) throws -> SimulatorController
}
