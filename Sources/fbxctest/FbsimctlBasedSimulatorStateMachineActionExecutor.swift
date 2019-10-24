import DeveloperDirLocator
import Foundation
import Logging
import Models
import PathLib
import ProcessController
import ResourceLocationResolver
import SimulatorPool

public final class FbsimctlBasedSimulatorStateMachineActionExecutor: SimulatorStateMachineActionExecutor, CustomStringConvertible {
    private let fbsimctl: ResolvableResourceLocation
    private var simulatorKeepAliveProcessController: ProcessController?
    private let workingDirectory: AbsolutePath

    public init(
        fbsimctl: ResolvableResourceLocation,
        workingDirectory: AbsolutePath
    ) {
        self.fbsimctl = fbsimctl
        self.workingDirectory = workingDirectory
    }

    public func performCreateSimulatorAction(
        environment: [String : String],
        testDestination: TestDestination
    ) throws -> SimulatorInfo {
        let simulatorSetPath = workingDirectory
            .appending(component: testDestination.deviceType)
            .appending(component: testDestination.runtime)
            .appending(component: "sim")
        
        try FileManager.default.createDirectory(atPath: workingDirectory)
        
        let processController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    fbsimctlArg,
                    "--json", "--set", simulatorSetPath,
                    "create",
                    "iOS \(testDestination.runtime)", testDestination.deviceType
                ],
                environment: environment
            )
        )

        let fbsimctlEvents = try waitForFbsimctlToCreateSimulator(processController: processController)
        let createEndedEvents = fbsimctlEvents.compactMap { $0 as? FbSimCtlCreateEndedEvent }
        guard createEndedEvents.count == 1, let createEndedEvent = createEndedEvents.first else {
            throw FbsimctlError.createOperationFailed("Failed to get single create ended event")
        }
        let simulatorUuid = createEndedEvent.subject.udid
        Logger.debug("Created simulator with UUID: \(simulatorUuid)")
        
        return SimulatorInfo(
            simulatorUuid: simulatorUuid,
            simulatorPath: simulatorSetPath.appending(component: simulatorUuid).pathString,
            testDestination: testDestination
        )
    }
    
    public func performBootSimulatorAction(
        environment: [String : String],
        simulatorInfo: SimulatorInfo
    ) throws {
        let processController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    fbsimctlArg,
                    "--json", "--set", simulatorInfo.simulatorSetPath,
                    simulatorInfo.simulatorUuid, "boot",
                    "--locale", "ru_US",
                    "--direct-launch", "--", "listen"
                ],
                environment: environment
            )
        )
        try waitForFbsimctlToBootSimulator(processController: processController)

        // process should be alive at this point and the boot should have finished
        guard processController.isProcessRunning == true else {
            throw FbsimctlError.bootOperationFailed("Simulator keep-alive process died unexpectedly")
        }

        // we keep this process alive throughout the run, as it owns the simulator process.
        simulatorKeepAliveProcessController = processController
    }
    
    public func performShutdownSimulatorAction(
        environment: [String : String],
        simulatorInfo: SimulatorInfo
    ) throws {
        if let simulatorKeepAliveProcessController = simulatorKeepAliveProcessController {
            simulatorKeepAliveProcessController.interruptAndForceKillIfNeeded()
            simulatorKeepAliveProcessController.waitForProcessToDie()
        }
        simulatorKeepAliveProcessController = nil

        let shutdownController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    "/usr/bin/xcrun",
                    "simctl", "--set", simulatorInfo.simulatorSetPath,
                    "shutdown", simulatorInfo.simulatorUuid
                ],
                environment: environment,
                silenceBehavior: SilenceBehavior(
                    automaticAction: .interruptAndForceKill,
                    allowedSilenceDuration: 20
                )
            )
        )
        shutdownController.startAndListenUntilProcessDies()
    }
    
    public func performDeleteSimulatorAction(
        environment: [String : String],
        simulatorInfo: SimulatorInfo
    ) throws {
        if let simulatorKeepAliveProcessController = simulatorKeepAliveProcessController {
            simulatorKeepAliveProcessController.interruptAndForceKillIfNeeded()
            simulatorKeepAliveProcessController.waitForProcessToDie()
        }
        simulatorKeepAliveProcessController = nil
        
        let controller = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    fbsimctlArg,
                    "--json",
                    "--set", simulatorInfo.simulatorSetPath,
                    simulatorInfo.simulatorUuid, "delete"
                ],
                environment: environment,
                silenceBehavior: SilenceBehavior(
                    automaticAction: .interruptAndForceKill,
                    allowedSilenceDuration: 30
                )
            )
        )
        controller.startAndListenUntilProcessDies()
    }

    // MARK: - Utility Methods

    private func waitForFbsimctlToCreateSimulator(
        processController: ProcessController
    ) throws -> [FbSimCtlEventCommonFields] {
        let outputProcessor = FbsimctlOutputProcessor(processController: processController)
        return try outputProcessor.waitForEvent(type: .ended, name: .create, timeout: 60)
    }

    private func waitForFbsimctlToBootSimulator(processController: ProcessController) throws {
        let outputProcessor = FbsimctlOutputProcessor(processController: processController)
        try outputProcessor.waitForEvent(type: .ended, name: .boot, timeout: 180)
        try outputProcessor.waitForEvent(type: .started, name: .listen, timeout: 60)
    }

    public var description: String {
        return "fbsimctl"
    }
    
    private var fbsimctlArg: SubprocessArgument {
        return fbsimctl.asArgumentWith(implicitFilenameInArchive: "fbsimctl")
    }

    // MARK: - Errors

    private enum FbsimctlError: Error, CustomStringConvertible {
        case createOperationFailed(String)
        case bootOperationFailed(String)

        var description: String {
            switch self {
            case .createOperationFailed(let message):
                return "Failed to create simulator: \(message)"
            case .bootOperationFailed(let message):
                return "Failed to boot simulator: \(message)"
            }
        }
    }
}
