import Foundation

public struct RuntimeDumpConfiguration {
    
    /** Timeout values. */
    public let testTimeoutConfiguration: TestTimeoutConfiguration
    
    /** Parameters that determinte how to execute the tests. */
    public let testRunExecutionBehavior: TestRunExecutionBehavior
    
    /** Path to logic test runner. */
    public let fbxctest: FbxctestLocation
    
    /** Xctest bundle which contents should be dumped in runtime */
    public let xcTestBundle: XcTestBundle

    /** Optional path app test dump*/
    public let applicationTestSupport: RuntimeDumpApplicationTestSupport?
    
    /** Test destination */
    public let testDestination: TestDestination
    
    /** Tests that are expected to run, so runtime dump can validate their presence. */
    public let testsToValidate: [TestToRun]

    public init(
        fbxctest: FbxctestLocation,
        xcTestBundle: XcTestBundle,
        applicationTestSupport: RuntimeDumpApplicationTestSupport?,
        testDestination: TestDestination,
        testsToValidate: [TestToRun]
    ) {
        self.testTimeoutConfiguration = TestTimeoutConfiguration(
            singleTestMaximumDuration: 20,
            fbxctestSilenceMaximumDuration: 20
        )
        self.testRunExecutionBehavior = TestRunExecutionBehavior(
            numberOfSimulators: 1,
            scheduleStrategy: .individual
        )
        self.fbxctest = fbxctest
        self.xcTestBundle = xcTestBundle
        self.applicationTestSupport = applicationTestSupport
        self.testDestination = testDestination
        self.testsToValidate = testsToValidate
    }
}
