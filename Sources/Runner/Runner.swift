import DeveloperDirLocator
import EventBus
import Foundation
import LocalHostDeterminer
import Logging
import Metrics
import Models
import ProcessController
import ResourceLocationResolver
import SimulatorPool
import TemporaryStuff
import TestsWorkingDirectorySupport

public final class Runner {
    private let configuration: RunnerConfiguration
    private let developerDirLocator: DeveloperDirLocator
    private let eventBus: EventBus
    private let resourceLocationResolver: ResourceLocationResolver
    private let tempFolder: TemporaryFolder
    private let testRunnerProvider: TestRunnerProvider
    
    public init(
        configuration: RunnerConfiguration,
        developerDirLocator: DeveloperDirLocator,
        eventBus: EventBus,
        resourceLocationResolver: ResourceLocationResolver,
        tempFolder: TemporaryFolder,
        testRunnerProvider: TestRunnerProvider
    ) {
        self.configuration = configuration
        self.developerDirLocator = developerDirLocator
        self.eventBus = eventBus
        self.resourceLocationResolver = resourceLocationResolver
        self.tempFolder = tempFolder
        self.testRunnerProvider = testRunnerProvider
    }
    
    /** Runs the given tests, attempting to restart the runner in case of crash. */
    public func run(
        entries: [TestEntry],
        developerDir: DeveloperDir,
        simulatorInfo: SimulatorInfo
    ) throws -> RunnerRunResult {
        if entries.isEmpty {
            return RunnerRunResult(
                entriesToRun: entries,
                testEntryResults: [],
                subprocessStandardStreamsCaptureConfig: nil
            )
        }
        
        let runResult = RunResult()
        
        // To not retry forever.
        // It is unlikely that multiple revives would provide any results, so we leave only a single retry.
        let numberOfAttemptsToRevive = 1
        
        // Something may crash (fbxctest/xctest), many tests may be not started. Some external code that uses Runner
        // may have its own logic for restarting particular tests, but here at Runner we deal with crashes of bunches
        // of tests, many of which can be even not started. Simplifying this: if something that runs tests is crashed,
        // we should retry running tests more than if some test fails. External code will treat failed tests as it
        // is promblem in them, not in infrastructure.
        
        var reviveAttempt = 0
        var lastSubprocessStandardStreamsCaptureConfig: StandardStreamsCaptureConfig? = nil
        while runResult.nonLostTestEntryResults.count < entries.count, reviveAttempt <= numberOfAttemptsToRevive {
            let entriesToRun = missingEntriesForScheduledEntries(
                expectedEntriesToRun: entries,
                collectedResults: runResult
            )
            let runResults = try runOnce(
                entriesToRun: entriesToRun,
                developerDir: developerDir,
                simulatorInfo: simulatorInfo
            )
            lastSubprocessStandardStreamsCaptureConfig = runResults.subprocessStandardStreamsCaptureConfig
            
            runResult.append(testEntryResults: runResults.testEntryResults)
            
            if runResults.testEntryResults.filter({ !$0.isLost }).isEmpty {
                // Here, if we do not receive events at all, we will get 0 results. We try to revive a limited number of times.
                reviveAttempt += 1
                Logger.warning("Got no results. Attempting to revive #\(reviveAttempt) out of allowed \(numberOfAttemptsToRevive) attempts to revive")
            } else {
                // Here, we actually got events, so we could reset revive attempts.
                reviveAttempt = 0
            }
        }
        
        return RunnerRunResult(
            entriesToRun: entries,
            testEntryResults: testEntryResults(
                runResult: runResult,
                simulatorId: simulatorInfo.simulatorUuid
            ),
            subprocessStandardStreamsCaptureConfig: lastSubprocessStandardStreamsCaptureConfig
        )
    }
    
    /// Runs the given tests once without any attempts to restart the failed or crashed tests.
    public func runOnce(
        entriesToRun: [TestEntry],
        developerDir: DeveloperDir,
        simulatorInfo: SimulatorInfo
    ) throws -> RunnerRunResult {
        if entriesToRun.isEmpty {
            Logger.info("Nothing to run!")
            return RunnerRunResult(
                entriesToRun: entriesToRun,
                testEntryResults: [],
                subprocessStandardStreamsCaptureConfig: nil
            )
        }

        var collectedTestStoppedEvents = [TestStoppedEvent]()
        
        let testContext = try createTestContext(
            developerDir: developerDir,
            simulatorInfo: simulatorInfo
        )
        
        Logger.info("Will run \(entriesToRun.count) tests on simulator \(simulatorInfo)")
        eventBus.post(event: .runnerEvent(.willRun(testEntries: entriesToRun, testContext: testContext)))

        let standardStreamsCaptureConfig = runTestsViaTestRunner(
            testRunner: try testRunnerProvider.testRunner(testRunnerTool: configuration.testRunnerTool),
            entriesToRun: entriesToRun,
            testContext: testContext,
            testRunnerStream: TestRunnerStreamWrapper(
                onTestStarted: { [weak self] testName in
                    self?.testStarted(
                        entriesToRun: entriesToRun,
                        testContext: testContext,
                        testName: testName
                    )
                },
                onTestStopped: { [weak self] testStoppedEvent in
                    collectedTestStoppedEvents.append(testStoppedEvent)
                    self?.testStopped(
                        entriesToRun: entriesToRun,
                        testContext: testContext,
                        testStoppedEvent: testStoppedEvent
                    )
                }
            )
        )
        
        let result = prepareResults(
            collectedTestStoppedEvents: collectedTestStoppedEvents,
            requestedEntriesToRun: entriesToRun,
            simulatorId: simulatorInfo.simulatorUuid
        )
        
        eventBus.post(event: .runnerEvent(.didRun(results: result, testContext: testContext)))
        
        Logger.info("Attempted to run \(entriesToRun.count) tests on simulator \(simulatorInfo): \(entriesToRun)")
        Logger.info("Did get \(result.count) results: \(result)")
        
        return RunnerRunResult(
            entriesToRun: entriesToRun,
            testEntryResults: result,
            subprocessStandardStreamsCaptureConfig: standardStreamsCaptureConfig
        )
    }
    
    private func createTestContext(
        developerDir: DeveloperDir,
        simulatorInfo: SimulatorInfo
    ) throws -> TestContext {
        let testsWorkingDirectory = try tempFolder.pathByCreatingDirectories(
            components: ["testsWorkingDir", UUID().uuidString]
        )

        var environment = configuration.environment
        environment[TestsWorkingDirectorySupport.envTestsWorkingDirectory] = testsWorkingDirectory.pathString
        environment["DEVELOPER_DIR"] = try developerDirLocator.path(developerDir: developerDir).pathString

        return TestContext(
            developerDir: developerDir,
            environment: environment,
            simulatorInfo: simulatorInfo
        )
    }
    
    private func runTestsViaTestRunner(
        testRunner: TestRunner,
        entriesToRun: [TestEntry],
        testContext: TestContext,
        testRunnerStream: TestRunnerStream
    ) -> StandardStreamsCaptureConfig {
        do {
            return try testRunner.run(
                buildArtifacts: configuration.buildArtifacts,
                developerDirLocator: developerDirLocator,
                entriesToRun: entriesToRun,
                maximumAllowedSilenceDuration: configuration.maximumAllowedSilenceDuration,
                simulatorSettings: configuration.simulatorSettings,
                singleTestMaximumDuration: configuration.singleTestMaximumDuration,
                testContext: testContext,
                testRunnerStream: testRunnerStream,
                testType: configuration.testType,
                temporaryFolder: tempFolder
            )
        } catch {
            return generateTestFailuresBecauseOfRunnerFailure(
                runnerError: error,
                entriesToRun: entriesToRun,
                testRunnerStream: testRunnerStream
            )
        }
    }
    
    private func generateTestFailuresBecauseOfRunnerFailure(
        runnerError: Error,
        entriesToRun: [TestEntry],
        testRunnerStream: TestRunnerStream
    ) -> StandardStreamsCaptureConfig {
        for testEntry in entriesToRun {
            testRunnerStream.testStarted(testName: testEntry.testName)
            testRunnerStream.testStopped(
                testStoppedEvent: TestStoppedEvent(
                    testName: testEntry.testName,
                    result: .lost,
                    testDuration: 0,
                    testExceptions: [
                        TestException(reason: RunnerConstants.failedToStartTestRunner.rawValue + ": \(runnerError)", filePathInProject: #file, lineNumber: #line)
                    ],
                    testStartTimestamp: Date().timeIntervalSince1970
                )
            )
        }
        return StandardStreamsCaptureConfig()
    }
    
    private func prepareResults(
        collectedTestStoppedEvents: [TestStoppedEvent],
        requestedEntriesToRun: [TestEntry],
        simulatorId: String
    ) -> [TestEntryResult] {
        return requestedEntriesToRun.map { requestedEntryToRun in
            prepareResult(
                requestedEntryToRun: requestedEntryToRun,
                simulatorId: simulatorId,
                collectedTestStoppedEvents: collectedTestStoppedEvents
            )
        }
    }
    
    private func prepareResult(
        requestedEntryToRun: TestEntry,
        simulatorId: String,
        collectedTestStoppedEvents: [TestStoppedEvent]
    ) -> TestEntryResult {
        let correspondingTestStoppedEvents = testStoppedEvents(
            testName: requestedEntryToRun.testName,
            collectedTestStoppedEvents: collectedTestStoppedEvents
        )
        return testEntryResultForFinishedTest(
            simulatorId: simulatorId,
            testEntry: requestedEntryToRun,
            testStoppedEvents: correspondingTestStoppedEvents
        )
    }
    
    private func testEntryResultForFinishedTest(
        simulatorId: String,
        testEntry: TestEntry,
        testStoppedEvents: [TestStoppedEvent]
    ) -> TestEntryResult {
        guard !testStoppedEvents.isEmpty else {
            return .lost(testEntry: testEntry)
        }
        return TestEntryResult.withResults(
            testEntry: testEntry,
            testRunResults: testStoppedEvents.map { testStoppedEvent -> TestRunResult in
                TestRunResult(
                    succeeded: testStoppedEvent.succeeded,
                    exceptions: testStoppedEvent.testExceptions,
                    duration: testStoppedEvent.testDuration,
                    startTime: testStoppedEvent.testStartTimestamp,
                    hostName: LocalHostDeterminer.currentHostAddress,
                    simulatorId: simulatorId
                )
            }
        )
    }
    
    private func testStoppedEvents(
        testName: TestName,
        collectedTestStoppedEvents: [TestStoppedEvent]
    ) -> [TestStoppedEvent] {
        return collectedTestStoppedEvents.filter { $0.testName == testName }
    }
    
    private func missingEntriesForScheduledEntries(
        expectedEntriesToRun: [TestEntry],
        collectedResults: RunResult)
        -> [TestEntry]
    {
        let receivedTestEntries = Set(collectedResults.nonLostTestEntryResults.map { $0.testEntry })
        return expectedEntriesToRun.filter { !receivedTestEntries.contains($0) }
    }
    
    private func testEntryResults(
        runResult: RunResult,
        simulatorId: String
    ) -> [TestEntryResult] {
        return runResult.testEntryResults.map {
            if $0.isLost {
                return resultForSingleTestThatDidNotRun(
                    simulatorId: simulatorId,
                    testEntry: $0.testEntry
                )
            } else {
                return $0
            }
        }
    }
    
    private func resultForSingleTestThatDidNotRun(
        simulatorId: String,
        testEntry: TestEntry
    ) -> TestEntryResult {
        return .withResult(
            testEntry: testEntry,
            testRunResult: TestRunResult(
                succeeded: false,
                exceptions: [
                    TestException(
                        reason: RunnerConstants.testDidNotRun.rawValue,
                        filePathInProject: #file,
                        lineNumber: #line
                    )
                ],
                duration: 0,
                startTime: Date().timeIntervalSince1970,
                hostName: LocalHostDeterminer.currentHostAddress,
                simulatorId: simulatorId
            )
        )
    }
    
    private func testEntryToRun(entriesToRun: [TestEntry], testName: TestName) -> TestEntry? {
        return entriesToRun.first(where: { (testEntry: TestEntry) -> Bool in
            testEntry.testName == testName
        })
    }

    // MARK: - Test Event Stream Handling

    private func testStarted(
        entriesToRun: [TestEntry],
        testContext: TestContext,
        testName: TestName
    ) {
        guard let testEntry = testEntryToRun(entriesToRun: entriesToRun, testName: testName) else {
            Logger.error("Can't find test entry for test \(testName)")
            return
        }
        
        eventBus.post(
            event: .runnerEvent(.testStarted(testEntry: testEntry, testContext: testContext))
        )
        
        MetricRecorder.capture(
            TestStartedMetric(
                host: LocalHostDeterminer.currentHostAddress,
                testClassName: testEntry.testName.className,
                testMethodName: testEntry.testName.methodName
            )
        )
    }
    
    private func testStopped(
        entriesToRun: [TestEntry],
        testContext: TestContext,
        testStoppedEvent: TestStoppedEvent
    ) {
        guard let testEntry = testEntryToRun(entriesToRun: entriesToRun, testName: testStoppedEvent.testName) else {
            Logger.error("Can't find test entry for test \(testStoppedEvent.testName)")
            return
        }
        
        eventBus.post(
            event: .runnerEvent(.testFinished(testEntry: testEntry, succeeded: testStoppedEvent.succeeded, testContext: testContext))
        )
        
        MetricRecorder.capture(
            TestFinishedMetric(
                result: testStoppedEvent.result.rawValue,
                host: LocalHostDeterminer.currentHostAddress,
                testClassName: testStoppedEvent.testName.className,
                testMethodName: testStoppedEvent.testName.methodName,
                testsFinishedCount: 1
            ),
            TestDurationMetric(
                result: testStoppedEvent.result.rawValue,
                host: LocalHostDeterminer.currentHostAddress,
                testClassName: testStoppedEvent.testName.className,
                testMethodName: testStoppedEvent.testName.methodName,
                duration: testStoppedEvent.testDuration
            )
        )
    }
}
