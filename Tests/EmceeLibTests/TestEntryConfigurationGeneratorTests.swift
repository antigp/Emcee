import EmceeLib
import Foundation
import Models
import ModelsTestHelpers
import XCTest

final class TestEntryConfigurationGeneratorTests: XCTestCase {
    let argFileTestToRun1 = TestName(className: "classFromArgs", methodName: "test1")
    let argFileTestToRun2 = TestName(className: "classFromArgs", methodName: "test2")
    
    let buildArtifacts = BuildArtifactsFixtures.withLocalPaths(
        appBundle: "1",
        runner: "1",
        xcTestBundle: "1",
        additionalApplicationBundles: ["1", "2"]
    )
    let argFileDestination1 = try! TestDestination(deviceType: UUID().uuidString, runtime: "10.1")
    let argFileDestination2 = try! TestDestination(deviceType: UUID().uuidString, runtime: "10.2")
    let simulatorSettings = SimulatorSettings(simulatorLocalizationSettings: nil, watchdogSettings: nil, preBootGlobalPreference: nil)
    let testTimeoutConfiguration = TestTimeoutConfiguration(singleTestMaximumDuration: 10, testRunnerMaximumSilenceDuration: 20)

    lazy var validatedEntries: [ValidatedTestEntry] = {
        return [
            ValidatedTestEntry(
                testName: argFileTestToRun1,
                testEntries: [TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test1")],
                buildArtifacts: buildArtifacts
            ),
            ValidatedTestEntry(
                testName: argFileTestToRun2,
                testEntries: [TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test2")],
                buildArtifacts: buildArtifacts
            )
        ]
    }()
    
    func test() {
        let generator = TestEntryConfigurationGenerator(
            validatedEntries: validatedEntries,
            testArgFileEntry: TestArgFile.Entry(
                buildArtifacts: buildArtifacts,
                environment: [:],
                numberOfRetries: 10,
                scheduleStrategy: .unsplit,
                simulatorSettings: simulatorSettings,
                testDestination: argFileDestination1,
                testTimeoutConfiguration: testTimeoutConfiguration,
                testType: .uiTest,
                testsToRun: [.testName(argFileTestToRun1)],
                toolResources: ToolResourcesFixtures.fakeToolResources(),
                toolchainConfiguration: ToolchainConfiguration(developerDir: .current)
            )
        )
        
        let configurations = generator.createTestEntryConfigurations()
        
        let expectedConfigurations = TestEntryConfigurationFixtures()
            .add(testEntry: TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test1"))
            .with(buildArtifacts: buildArtifacts)
            .with(simulatorSettings: simulatorSettings)
            .with(testDestination: argFileDestination1)
            .with(testTimeoutConfiguration: testTimeoutConfiguration)
            .with(testExecutionBehavior: TestExecutionBehavior(environment: [:], numberOfRetries: 10))
            .with(testType: .uiTest)
            .testEntryConfigurations()
        
        XCTAssertEqual(Set(configurations), Set(expectedConfigurations))
    }
    
    func test_repeated_items() {
        let generator = TestEntryConfigurationGenerator(
            validatedEntries: validatedEntries,
            testArgFileEntry: TestArgFile.Entry(
                buildArtifacts: buildArtifacts,
                environment: [:],
                numberOfRetries: 10,
                scheduleStrategy: .unsplit,
                simulatorSettings: simulatorSettings,
                testDestination: argFileDestination1,
                testTimeoutConfiguration: testTimeoutConfiguration,
                testType: .uiTest,
                testsToRun: [.testName(argFileTestToRun1), .testName(argFileTestToRun1)],
                toolResources: ToolResourcesFixtures.fakeToolResources(),
                toolchainConfiguration: ToolchainConfiguration(developerDir: .current)
            )
        )
        
        let expectedTestEntryConfigurations =
            TestEntryConfigurationFixtures()
                .add(testEntry: TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test1"))
                .with(buildArtifacts: buildArtifacts)
                .with(simulatorSettings: simulatorSettings)
                .with(testExecutionBehavior: TestExecutionBehavior(environment: [:], numberOfRetries: 10))
                .with(testDestination: argFileDestination1)
                .with(testTimeoutConfiguration: testTimeoutConfiguration)
                .with(testType: .uiTest)
                .testEntryConfigurations()
        
        XCTAssertEqual(
            generator.createTestEntryConfigurations(),
            expectedTestEntryConfigurations + expectedTestEntryConfigurations
        )
    }
    
    func test__all_available_tests() {
        let generator = TestEntryConfigurationGenerator(
            validatedEntries: validatedEntries,
            testArgFileEntry: TestArgFile.Entry(
                buildArtifacts: buildArtifacts,
                environment: [:],
                numberOfRetries: 10,
                scheduleStrategy: .unsplit,
                simulatorSettings: simulatorSettings,
                testDestination: argFileDestination1,
                testTimeoutConfiguration: testTimeoutConfiguration,
                testType: .uiTest,
                testsToRun: [.allProvidedByRuntimeDump],
                toolResources: ToolResourcesFixtures.fakeToolResources(),
                toolchainConfiguration: ToolchainConfiguration(developerDir: .current)
            )
        )
        
        let expectedConfigurations = [
            TestEntryConfigurationFixtures()
                .add(testEntry: TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test1"))
                .with(buildArtifacts: buildArtifacts)
                .with(testDestination: argFileDestination1)
                .with(testExecutionBehavior: TestExecutionBehavior(environment: [:], numberOfRetries: 10))
                .with(testTimeoutConfiguration: testTimeoutConfiguration)
                .with(testType: .uiTest)
                .testEntryConfigurations(),
            TestEntryConfigurationFixtures()
                .add(testEntry: TestEntryFixtures.testEntry(className: "classFromArgs", methodName: "test2"))
                .with(buildArtifacts: buildArtifacts)
                .with(testDestination: argFileDestination1)
                .with(testExecutionBehavior: TestExecutionBehavior(environment: [:], numberOfRetries: 10))
                .with(testTimeoutConfiguration: testTimeoutConfiguration)
                .with(testType: .uiTest)
                .testEntryConfigurations()
            ].flatMap { $0 }
        
        XCTAssertEqual(
            Set(generator.createTestEntryConfigurations()),
            Set(expectedConfigurations)
        )
    }
}
