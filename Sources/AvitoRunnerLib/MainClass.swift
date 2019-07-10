import Foundation
import Logging
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
        let exitCode: Int32
        do {
            try startTrackingParentProcessAliveness()
            
            try InProcessMain().run()
            exitCode = 0
        } catch {
            Logger.error("\(error)")
            print("Execution error occured: \(error)")
            exitCode = 1
        }
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
