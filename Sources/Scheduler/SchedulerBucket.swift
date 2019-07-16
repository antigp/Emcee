import Foundation
import Models

public final class SchedulerBucket: CustomStringConvertible, Equatable {
    public let bucketId: BucketId
    public let testEntries: [TestEntry]
    public let buildArtifacts: BuildArtifacts
    public let simulatorSettings: SimulatorSettings
    public let testDestination: TestDestination
    public let testExecutionBehavior: TestExecutionBehavior
    public let testType: TestType
    public let toolchainConfiguration: ToolchainConfiguration
    
    public var description: String {
        return "<\((type(of: self))) bucketId=\(bucketId)>"
    }

    public init(
        bucketId: BucketId,
        testEntries: [TestEntry],
        buildArtifacts: BuildArtifacts,
        simulatorSettings: SimulatorSettings,
        testDestination: TestDestination,
        testExecutionBehavior: TestExecutionBehavior,
        testType: TestType,
        toolchainConfiguration: ToolchainConfiguration
    ) {
        self.bucketId = bucketId
        self.testEntries = testEntries
        self.buildArtifacts = buildArtifacts
        self.simulatorSettings = simulatorSettings
        self.testDestination = testDestination
        self.testExecutionBehavior = testExecutionBehavior
        self.testType = testType
        self.toolchainConfiguration = toolchainConfiguration
    }
    
    public static func from(bucket: Bucket, testExecutionBehavior: TestExecutionBehavior) -> SchedulerBucket {
        return SchedulerBucket(
            bucketId: bucket.bucketId,
            testEntries: bucket.testEntries,
            buildArtifacts: bucket.buildArtifacts,
            simulatorSettings: bucket.simulatorSettings,
            testDestination: bucket.testDestination,
            testExecutionBehavior: testExecutionBehavior,
            testType: bucket.testType,
            toolchainConfiguration: bucket.toolchainConfiguration
        )
    }
    
    public static func == (left: SchedulerBucket, right: SchedulerBucket) -> Bool {
        return left.bucketId == right.bucketId
            && left.testEntries == right.testEntries
            && left.buildArtifacts == right.buildArtifacts
            && left.simulatorSettings == right.simulatorSettings
            && left.testDestination == right.testDestination
            && left.testExecutionBehavior == right.testExecutionBehavior
            && left.testType == right.testType
            && left.toolchainConfiguration == right.toolchainConfiguration
    }
}
