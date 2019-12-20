import Foundation
import Models
import ModelsTestHelpers
import TestHelpers
import XCTest

final class TestArgFileTests: XCTestCase {
    func test___decoding_full_json() throws {
        let json = """
            {
                "testsToRun": [
                    {"predicateType": "singleTestName", "testName": "ClassName/testMethod"}
                ],
                "environment": {"value": "key"},
                "numberOfRetries": 42,
                "testDestination": {"deviceType": "iPhone SE", "runtime": "11.3"},
                "testType": "logicTest",
                "buildArtifacts": {
                    "appBundle": "/appBundle",
                    "runner": "/runner",
                    "xcTestBundle": {
                        "location": "/xcTestBundle",
                        "runtimeDumpKind": "appTest"
                    },
                    "additionalApplicationBundles": ["/additionalApp1", "/additionalApp2"],
                    "needHostAppToDumpTests": true
                },
                "toolResources": {
                    "testRunnerTool": {"toolType": "fbxctest", "fbxctestLocation": "http://example.com/fbxctest.zip"},
                    "simulatorControlTool": {"toolType": "fbsimctl", "location": "http://example.com/fbsimctl.zip"}
                },
                "toolchainConfiguration": {"developerDir": {"kind": "current"}},
                "scheduleStrategy": "unsplit",
                "simulatorSettings": {
                    "simulatorLocalizationSettings": "/l10n",
                    "watchdogSettings": "/wd"
                },
                "testTimeoutConfiguration": {
                    "singleTestMaximumDuration": 42,
                    "testRunnerMaximumSilenceDuration": 24
                }
            }
        """.data(using: .utf8)!
        
        let entry = assertDoesNotThrow {
            try JSONDecoder().decode(TestArgFile.Entry.self, from: json)
        }

        XCTAssertEqual(
            entry,
            TestArgFile.Entry(
                buildArtifacts: buildArtifacts(),
                environment: ["value": "key"],
                numberOfRetries: 42,
                scheduleStrategy: .unsplit,
                simulatorSettings: SimulatorSettings(
                    simulatorLocalizationSettings: SimulatorLocalizationLocation(.localFilePath("/l10n")),
                    watchdogSettings: WatchdogSettingsLocation(.localFilePath("/wd")),
                    preBootGlobalPreference: nil
                ),
                testDestination: try TestDestination(deviceType: "iPhone SE", runtime: "11.3"),
                testTimeoutConfiguration: TestTimeoutConfiguration(
                    singleTestMaximumDuration: 42,
                    testRunnerMaximumSilenceDuration: 24
                ),
                testType: .logicTest,
                testsToRun: [.testName(TestName(className: "ClassName", methodName: "testMethod"))],
                toolResources: ToolResources(
                    simulatorControlTool: .fbsimctl(FbsimctlLocation(.remoteUrl(URL(string: "http://example.com/fbsimctl.zip")!))),
                    testRunnerTool: .fbxctest(FbxctestLocation(.remoteUrl(URL(string: "http://example.com/fbxctest.zip")!)))
                ),
                toolchainConfiguration: ToolchainConfiguration(developerDir: .current)
            )
        )
    }
    
    private func buildArtifacts(
        appBundle: String? = "/appBundle",
        runner: String? = "/runner",
        additionalApplicationBundles: [String] = ["/additionalApp1", "/additionalApp2"],
        runtimeDumpKind: XcTestBundleRuntimeDumpMode = .appTest
    ) -> BuildArtifacts {
        return BuildArtifactsFixtures.withLocalPaths(
            appBundle: appBundle,
            runner: runner,
            xcTestBundle: "/xcTestBundle",
            additionalApplicationBundles: additionalApplicationBundles,
            runtimeDumpKind: runtimeDumpKind
        )
    }
}

