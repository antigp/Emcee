import EventBus
import Extensions
import Foundation
import Logging
import Metrics
import Models
import ResourceLocationResolver
import Runner
import SimulatorPool
import SynchronousWaiter
import TempFolder

public final class RuntimeTestQuerier {
    private let eventBus: EventBus
    private let configuration: RuntimeDumpConfiguration
    private let testQueryEntry = TestEntry(className: "NonExistingTest", methodName: "fakeTest", caseId: nil)
    private let resourceLocationResolver: ResourceLocationResolver
    private let tempFolder: TempFolder
    static let runtimeTestsJsonFilename = "runtime_tests.json"
    
    public init(
        eventBus: EventBus,
        configuration: RuntimeDumpConfiguration,
        resourceLocationResolver: ResourceLocationResolver,
        tempFolder: TempFolder)
    {
        self.eventBus = eventBus
        self.configuration = configuration
        self.resourceLocationResolver = resourceLocationResolver
        self.tempFolder = tempFolder
    }
    
    public func queryRuntime() throws -> RuntimeQueryResult {
        let availableRuntimeTests = try runRetrying(times: 5) { try availableTestsInRuntime() }
        let unavailableTestEntries = requestedTestsNotAvailableInRuntime(availableRuntimeTests)
        return RuntimeQueryResult(
            unavailableTestsToRun: unavailableTestEntries,
            availableRuntimeTests: availableRuntimeTests
        )
    }
    
    private func runRetrying<T>(times: Int, _ work: () throws -> T) rethrows -> T {
        for retryIndex in 0 ..< times {
            do {
                return try work()
            } catch {
                Logger.error("Attempt \(retryIndex + 1) of \(times), got an error: \(error)")
                SynchronousWaiter.wait(timeout: TimeInterval(retryIndex) * 2.0)
            }
        }
        return try work()
    }
    
    private func availableTestsInRuntime() throws -> [RuntimeTestEntry] {
        let runtimeEntriesJSONPath = tempFolder.pathWith(components: [RuntimeTestQuerier.runtimeTestsJsonFilename])
        Logger.debug("Will dump runtime tests into file: \(runtimeEntriesJSONPath)")
        
        let runnerConfiguration = RunnerConfiguration(
            testType: .logicTest,
            runnerBinaryLocation: configuration.runnerBinaryLocation,
            buildArtifacts: BuildArtifacts.onlyWithXctestBundle(xcTestBundle: configuration.xcTestBundle),
            environment: configuration.testRunExecutionBehavior.environment.byMergingWith(
                ["AVITO_TEST_RUNNER_RUNTIME_TESTS_EXPORT_PATH": runtimeEntriesJSONPath.asString]
            ),
            simulatorSettings: SimulatorSettings(simulatorLocalizationSettings: nil, watchdogSettings: nil),
            testTimeoutConfiguration: configuration.testTimeoutConfiguration
        )
        let runner = Runner(
            eventBus: eventBus,
            configuration: runnerConfiguration,
            tempFolder: tempFolder,
            resourceLocationResolver: resourceLocationResolver
        )
        _ = try runner.runOnce(
            entriesToRun: [testQueryEntry],
            simulator: Shimulator.shimulator(
                testDestination: configuration.testDestination,
                workingDirectory: try tempFolder.pathByCreatingDirectories(components: ["shimulator"])
            )
        )
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: runtimeEntriesJSONPath.asString)),
            let foundTestEntries = try? JSONDecoder().decode([RuntimeTestEntry].self, from: data) else {
                throw TestExplorationError.fileNotFound(runtimeEntriesJSONPath.asString)
        }
        
        let allTests = foundTestEntries.flatMap { $0.testMethods }
        reportStats(testCaseCount: foundTestEntries.count, testCount: allTests.count)
        
        return foundTestEntries
    }
    
    private func requestedTestsNotAvailableInRuntime(_ runtimeDetectedEntries: [RuntimeTestEntry]) -> [TestToRun] {
        if configuration.testsToRun.isEmpty { return [] }
        if runtimeDetectedEntries.isEmpty { return configuration.testsToRun }
        
        let availableTestEntries = runtimeDetectedEntries.flatMap { runtimeDetectedTestEntry -> [TestEntry] in
            runtimeDetectedTestEntry.testMethods.map {
                TestEntry(className: runtimeDetectedTestEntry.className, methodName: $0, caseId: runtimeDetectedTestEntry.caseId)
            }
        }
        let testsToRunMissingInRuntime = configuration.testsToRun.filter { requestedTestToRun -> Bool in
            switch requestedTestToRun {
            case .testName(let requestedTestName):
                return availableTestEntries.first { $0.testName == requestedTestName } == nil
            case .caseId(let requestedCaseId):
                return availableTestEntries.first { $0.caseId == requestedCaseId } == nil
            }
        }
        return testsToRunMissingInRuntime
    }
    
    private func reportStats(testCaseCount: Int, testCount: Int) {
        let testBundleName = configuration.xcTestBundle.resourceLocation.stringValue.lastPathComponent
        Logger.info("Runtime dump contains \(testCaseCount) XCTestCases, \(testCount) tests")
        MetricRecorder.capture(
            RuntimeDumpTestCountMetric(testBundleName: testBundleName, numberOfTests: testCount),
            RuntimeDumpTestCaseCountMetric(testBundleName: testBundleName, numberOfTestCases: testCaseCount)
        )
    }
}
