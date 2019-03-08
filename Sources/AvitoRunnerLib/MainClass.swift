import ArgumentsParser
import Extensions
import Foundation
import LocalHostDeterminer
import Logging
import LoggingSetup
import Metrics
import ProcessController

public final class Main {
    public init() {}
    
    public func main() -> Int32 {
        if shouldRunInProcess {
            return runInProcess()
        } else {
            return runOutOfProcessAndCleanup()
        }
    }
    
    private static let runInProcessEnvName = "AVITO_RUNNER_RUN_IN_PROCESS"
    private var shouldRunInProcess: Bool {
        return ProcessInfo.processInfo.environment[Main.runInProcessEnvName] == "true"
    }
    
    private var parentProcessTracker: ParentProcessTracker?
    
    private func runInProcess() -> Int32 {
        try! LoggingSetup.setupLogging(stderrVerbosity: Verbosity.verboseDebug)
        defer { LoggingSetup.tearDown() }
        
        Logger.info("Arguments: \(ProcessInfo.processInfo.arguments)")
        
        var registry = CommandRegistry(
            usage: "<subcommand> <options>",
            overview: "Runs specific tasks related to iOS UI testing"
        )
        
        registry.register(command: DistRunTestsCommand.self)
        registry.register(command: DistWorkCommand.self)
        registry.register(command: DumpRuntimeTestsCommand.self)
        registry.register(command: RunTestsCommand.self)
        registry.register(command: RunTestsOnRemoteQueueCommand.self)
        registry.register(command: StartQueueServerCommand.self)
        
        var userSelectedCommand: Command? = nil
        let exitCode: Int32
        do {
            try startTrackingParentProcessAliveness()
            try registry.run { determinedCommand in
                userSelectedCommand = determinedCommand
                MetricRecorder.capture(
                    LaunchMetric(
                        command: determinedCommand.command,
                        host: LocalHostDeterminer.currentHostAddress
                    )
                )
            }
            exitCode = 0
        } catch {
            Logger.error("\(error)")
            exitCode = 1
        }
        Logger.info("Finished executing with exit code \(exitCode)")
        
        MetricRecorder.capture(
            ExitCodeMetric(
                command: userSelectedCommand?.command ?? "not_determined_command",
                host: LocalHostDeterminer.currentHostAddress,
                exitCode: exitCode
            )
        )
        return exitCode
    }
    
    private func startTrackingParentProcessAliveness() throws {
        parentProcessTracker = try ParentProcessTracker {
            Logger.warning("Parent process has died")
            OrphanProcessTracker().killAll()
            exit(3)
        }
    }
    
    private static var innerProcess: Process?
    
    private func runOutOfProcessAndCleanup() -> Int32 {
        let process = Process()
        try? process.setStartsNewProcessGroup(false)
        
        signal(SIGINT, { _ in Main.innerProcess?.interrupt() })
        signal(SIGABRT, { _ in Main.innerProcess?.terminate() })
        signal(SIGTERM, { _ in Main.innerProcess?.terminate() })
        
        process.launchPath = ProcessInfo.processInfo.executablePath
        process.arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
        var environment = ProcessInfo.processInfo.environment
        environment[Main.runInProcessEnvName] = "true"
        environment[ParentProcessTracker.envName] = String(ProcessInfo.processInfo.processIdentifier)
        process.environment = environment
        Main.innerProcess = process
        process.launch()
        process.waitUntilExit()
        OrphanProcessTracker().killAll()
        return process.terminationStatus
    }
}
