import Foundation
import Models

public final class TestEntryConfigurationFixtures {
    public var buildArtifacts = BuildArtifactsFixtures.fakeEmptyBuildArtifacts()
    public var simulatorSettings = SimulatorSettings(simulatorLocalizationSettings: nil, watchdogSettings: nil, preBootGlobalPreference: nil)
    public var testDestination = TestDestinationFixtures.testDestination
    public var testEntries = [TestEntry]()
    public var testExecutionBehavior = TestExecutionBehavior(environment: [:], numberOfRetries: 0)
    public var testTimeoutConfiguration = TestTimeoutConfiguration(singleTestMaximumDuration: 0, testRunnerMaximumSilenceDuration: 0)
    public var testType = TestType.uiTest
    public var toolResources: ToolResources = ToolResourcesFixtures.fakeToolResources()
    public var toolchainConfiguration = ToolchainConfiguration(developerDir: .current)
    
    public init() {}
    
    public func add(testEntry: TestEntry) -> Self {
        testEntries.append(testEntry)
        return self
    }
    
    public func add(testEntries: [TestEntry]) -> Self {
        self.testEntries.append(contentsOf: testEntries)
        return self
    }
    
    public func with(buildArtifacts: BuildArtifacts) -> Self {
        self.buildArtifacts = buildArtifacts
        return self
    }
    
    public func with(simulatorSettings: SimulatorSettings) -> Self {
        self.simulatorSettings = simulatorSettings
        return self
    }
    
    public func with(testDestination: TestDestination) -> Self {
        self.testDestination = testDestination
        return self
    }
    
    public func with(testExecutionBehavior: TestExecutionBehavior) -> Self {
        self.testExecutionBehavior = testExecutionBehavior
        return self
    }
    
    public func with(testTimeoutConfiguration: TestTimeoutConfiguration) -> Self {
        self.testTimeoutConfiguration = testTimeoutConfiguration
        return self
    }
    
    public func with(testType: TestType) -> Self {
        self.testType = testType
        return self
    }
    
    public func with(toolResources: ToolResources) -> Self {
        self.toolResources = toolResources
        return self
    }
    
    public func with(toolchainConfiguration: ToolchainConfiguration) -> Self {
        self.toolchainConfiguration = toolchainConfiguration
        return self
    }
    
    public func testEntryConfigurations() -> [TestEntryConfiguration] {
        return testEntries.map {
            TestEntryConfiguration(
                buildArtifacts: buildArtifacts,
                simulatorSettings: simulatorSettings,
                testDestination: testDestination,
                testEntry: $0,
                testExecutionBehavior: testExecutionBehavior,
                testTimeoutConfiguration: testTimeoutConfiguration,
                testType: testType,
                toolResources: ToolResourcesFixtures.fakeToolResources(),
                toolchainConfiguration: toolchainConfiguration
            )
        }
    }
}
