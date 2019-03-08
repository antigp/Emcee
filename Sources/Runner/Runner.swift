import EventBus
import Foundation
import LocalHostDeterminer
import Logging
import Metrics
import Models
import ProcessController
import ResourceLocationResolver
import SimulatorPool
import TempFolder
import TestsWorkingDirectorySupport
import fbxctest

/// This class runs the given tests on a single simulator.
public final class Runner {
    private let eventBus: EventBus
    private let configuration: RunnerConfiguration
    private let tempFolder: TempFolder
    private let resourceLocationResolver: ResourceLocationResolver
    
    public init(
        eventBus: EventBus,
        configuration: RunnerConfiguration,
        tempFolder: TempFolder,
        resourceLocationResolver: ResourceLocationResolver)
    {
        self.eventBus = eventBus
        self.configuration = configuration
        self.tempFolder = tempFolder
        self.resourceLocationResolver = resourceLocationResolver
    }
    
    /** Runs the given tests, attempting to restart the runner in case of crash. */
    public func run(
        entries: [TestEntry],
        simulator: Simulator
        ) throws -> [TestEntryResult]
    {
        if entries.isEmpty { return [] }
        
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
        while runResult.nonLostTestEntryResults.count < entries.count, reviveAttempt <= numberOfAttemptsToRevive {
            let entriesToRun = missingEntriesForScheduledEntries(
                expectedEntriesToRun: entries,
                collectedResults: runResult)
            let runResults = try runOnce(
                entriesToRun: entriesToRun,
                simulator: simulator
            )
            runResult.append(testEntryResults: runResults)
            
            if runResults.filter({ !$0.isLost }).isEmpty {
                // Here, if we do not receive events at all, we will get 0 results. We try to revive a limited number of times.
                reviveAttempt += 1
                Logger.warning("Got no results. Attempting to revive #\(reviveAttempt) out of allowed \(numberOfAttemptsToRevive) attempts to revive")
            } else {
                // Here, we actually got events, so we could reset revive attempts.
                reviveAttempt = 0
            }
        }
        
        return testEntryResults(runResult: runResult)
    }
    
    /** Runs the given tests once without any attempts to restart the failed/crashed tests. */
    public func runOnce(
        entriesToRun: [TestEntry],
        simulator: Simulator
        ) throws -> [TestEntryResult]
    {
        if entriesToRun.isEmpty {
            Logger.info("Nothing to run!")
            return []
        }
        
        Logger.info("Will run \(entriesToRun.count) tests on simulator \(simulator)")
        
        let testContext = createTestContext(simulator: simulator)
        
        eventBus.post(event: .runnerEvent(.willRun(testEntries: entriesToRun, testContext: testContext)))
        
        let fbxctestOutputProcessor = try FbxctestOutputProcessor(
            subprocess: createRunnerSubprocess(entriesToRun: entriesToRun, testContext: testContext)
                .with(maximumAllowedSilenceDuration: configuration.maximumAllowedSilenceDuration ?? 0),
            simulatorId: simulator.identifier,
            singleTestMaximumDuration: configuration.singleTestMaximumDuration,
            onTestStarted: { [weak self] event in self?.testStarted(event: event, testContext: testContext) },
            onTestStopped: { [weak self] pair in self?.testStopped(eventPair: pair, testContext: testContext) }
        )
        fbxctestOutputProcessor.processOutputAndWaitForProcessTermination()
        
        let result = prepareResults(
            requestedEntriesToRun: entriesToRun,
            testEventPairs: fbxctestOutputProcessor.testEventPairs
        )
        
        eventBus.post(event: .runnerEvent(.didRun(results: result, testContext: testContext)))
        
        Logger.info("Attempted to run \(entriesToRun.count) tests on simulator \(simulator): \(entriesToRun)")
        Logger.info("Did get \(result.count) results: \(result)")
        
        return result
    }

    private func createRunnerSubprocess(entriesToRun: [TestEntry], testContext: TestContext) -> Subprocess {
        let argumentListGenerator = RunnerArgumentListGeneratorProvider.runnerSubprocessGenerator(
            runnerBinaryLocation: configuration.runnerBinaryLocation
        )
        return argumentListGenerator.createSubprocess(
            buildArtifacts: configuration.buildArtifacts,
            entriesToRun: entriesToRun,
            testContext: testContext,
            resourceLocationResolver: resourceLocationResolver,
            runnerBinaryLocation: configuration.runnerBinaryLocation,
            tempFolder: tempFolder,
            testType: configuration.testType
        )
    }
    
    private func createTestContext(simulator: Simulator) -> TestContext {
        var environment = configuration.environment
        do {
            let testsWorkingDirectory = try tempFolder.pathByCreatingDirectories(components: ["testsWorkingDir", UUID().uuidString])
            environment[TestsWorkingDirectorySupport.envTestsWorkingDirectory] = testsWorkingDirectory.asString
        } catch {
            Logger.error("Unable to create path tests working directory: \(error)")
        }
        return TestContext(
            environment: environment,
            simulatorInfo: simulator.simulatorInfo
        )
    }
    
    private func prepareResults(
        requestedEntriesToRun: [TestEntry],
        testEventPairs: [TestEventPair])
        -> [TestEntryResult]
    {
        return requestedEntriesToRun.map { requestedEntryToRun in
            prepareResult(
                requestedEntryToRun: requestedEntryToRun,
                testEventPairs: testEventPairs
            )
        }
    }
    
    private func prepareResult(
        requestedEntryToRun: TestEntry,
        testEventPairs: [TestEventPair])
        -> TestEntryResult
    {
        let correspondingEventPair = testEventPairForEntry(
            requestedEntryToRun,
            testEventPairs: testEventPairs)
        
        if let correspondingEventPair = correspondingEventPair, let finishEvent = correspondingEventPair.finishEvent {
            return testEntryResultForFinishedTest(
                testEntry: requestedEntryToRun,
                startEvent: correspondingEventPair.startEvent,
                finishEvent: finishEvent
            )
        } else {
            return .lost(testEntry: requestedEntryToRun)
        }
    }
    
    private func testEntryResultForFinishedTest(
        testEntry: TestEntry,
        startEvent: TestStartedEvent,
        finishEvent: TestFinishedEvent
        ) -> TestEntryResult
    {
        return .withResult(
            testEntry: testEntry,
            testRunResult: TestRunResult(
                succeeded: finishEvent.succeeded,
                exceptions: finishEvent.exceptions.map { TestException(reason: $0.reason, filePathInProject: $0.filePathInProject, lineNumber: $0.lineNumber) },
                duration: finishEvent.totalDuration,
                startTime: startEvent.timestamp,
                finishTime: finishEvent.timestamp,
                hostName: startEvent.hostName ?? "host was not set to TestStartedEvent",
                processId: startEvent.processId ?? 0,
                simulatorId: startEvent.simulatorId ?? "unknown_simulator"
            )
        )
    }
    
    private func testEventPairForEntry(
        _ entry: TestEntry,
        testEventPairs: [TestEventPair])
        -> TestEventPair?
    {
        return testEventPairs.first(where: { $0.startEvent.testName == entry.testName })
    }
    
    private func missingEntriesForScheduledEntries(
        expectedEntriesToRun: [TestEntry],
        collectedResults: RunResult)
        -> [TestEntry]
    {
        let receivedTestEntries = Set(collectedResults.nonLostTestEntryResults.map { $0.testEntry })
        return expectedEntriesToRun.filter { !receivedTestEntries.contains($0) }
    }
    
    private func testEntryResults(runResult: RunResult) -> [TestEntryResult] {
        return runResult.testEntryResults.map {
            if $0.isLost {
                return resultForSingleTestThatDidNotRun(testEntry: $0.testEntry)
            } else {
                return $0
            }
        }
    }
    
    private func resultForSingleTestThatDidNotRun(testEntry: TestEntry) -> TestEntryResult {
        let timestamp = Date().timeIntervalSince1970
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
                startTime: timestamp,
                finishTime: timestamp,
                hostName: LocalHostDeterminer.currentHostAddress,
                processId: 0,
                simulatorId: "no_simulator"
            )
        )
    }
    
    private func testStarted(event: TestStartedEvent, testContext: TestContext) {
        eventBus.post(
            event: .runnerEvent(.testStarted(testEntry: event.testEntry, testContext: testContext))
        )
        
        MetricRecorder.capture(
            TestStartedMetric(
                host: event.hostName ?? "unknown_host",
                testClassName: event.testEntry.className,
                testMethodName: event.testEntry.methodName
            )
        )
    }
    
    private func testStopped(eventPair: TestEventPair, testContext: TestContext) {
        let event = eventPair.startEvent
        let succeeded = eventPair.finishEvent?.succeeded ?? false
        eventBus.post(
            event: .runnerEvent(.testFinished(testEntry: event.testEntry, succeeded: succeeded, testContext: testContext))
        )
        
        let testResult = eventPair.finishEvent?.result ?? "unknown_result"
        let testDuration = eventPair.finishEvent?.totalDuration ?? 0
        MetricRecorder.capture(
            TestFinishedMetric(
                result: testResult,
                host: eventPair.startEvent.hostName ?? "unknown_host",
                testClassName: event.testEntry.className,
                testMethodName: event.testEntry.methodName,
                testsFinishedCount: 1
            ),
            TestDurationMetric(
                result: testResult,
                host: eventPair.startEvent.hostName ?? "unknown_host",
                testClassName: event.testEntry.className,
                testMethodName: event.testEntry.methodName,
                duration: testDuration
            )
        )
    }
    
}
