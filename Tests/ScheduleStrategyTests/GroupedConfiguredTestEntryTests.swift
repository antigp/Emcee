@testable import ScheduleStrategy
import AppleTestModelsTestHelpers
import CommonTestModelsTestHelpers
import QueueModelsTestHelpers
import SimulatorPoolModels
import TestHelpers
import XCTest

final class GroupedConfiguredTestEntryTests: XCTestCase {
    
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test___grouping_into_same_group___when_all_fields_match() {
        let configuredTestEntry1 = ConfiguredTestEntryFixture()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class", methodName: "test1"))
            .build()
        
        let configuredTestEntry2 = ConfiguredTestEntryFixture()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class", methodName: "test2"))
            .build()
        
        let mixedConfiguredTestEntries = [
            configuredTestEntry1,
            configuredTestEntry2,
        ]
        
        let grouper = GroupedConfiguredTestEntry(configuredTestEntries: mixedConfiguredTestEntries)
        let groups = grouper.grouped()
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0], [configuredTestEntry1, configuredTestEntry2])
    }
    
    func test___grouping_by_TestEntryConfiguration() {
        let testEntryConfiguration1 = TestEntryConfigurationFixtures()
            .with(
                appleTestConfiguration: AppleTestConfigurationFixture()
                    .with(simRuntime: SimRuntime(fullyQualifiedId: "simruntime1"))
                    .appleTestConfiguration()
            )
            .testEntryConfiguration()
        
        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
            .with(
                appleTestConfiguration: AppleTestConfigurationFixture()
                    .with(developerDir: .useXcode(CFBundleShortVersionString: "12.34"))
                    .appleTestConfiguration()
            )
            .testEntryConfiguration()
        
        
        let configuredTestEntry1 = ConfiguredTestEntryFixture()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class", methodName: "test1"))
            .with(testEntryConfiguration: testEntryConfiguration1)
            .build()
        
        let configuredTestEntry2 = ConfiguredTestEntryFixture()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class", methodName: "test2"))
            .with(testEntryConfiguration: testEntryConfiguration1)
            .build()
        
        let configuredTestEntry3 = ConfiguredTestEntryFixture()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class", methodName: "test3"))
            .with(testEntryConfiguration: testEntryConfiguration2)
            .build()
        
        let mixedConfiguredTestEntries = [
            configuredTestEntry1,
            configuredTestEntry2,
            configuredTestEntry3,
        ]
        
        let grouper = GroupedConfiguredTestEntry(configuredTestEntries: mixedConfiguredTestEntries)
        let groups = grouper.grouped()
        
        assert {
            groups
        } equals: {
            [
                [configuredTestEntry1, configuredTestEntry2],
                [configuredTestEntry3],
            ]
        }
    }
//
//    func test___grouping_by_BuildArtifacts___preserves_order_and_sorts_by_test_count() {
//        let testEntryConfigurations1 = TestEntryConfigurationFixtures()
//            .with(
//                buildArtifacts: .iosLogicTests(
//                    xcTestBundle: XcTestBundle(
//                        location: TestBundleLocation(.localFilePath("/1")),
//                        testDiscoveryMode: .parseFunctionSymbols
//                    )
//                )
//            )
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class3", methodName: "test"))
//            .testEntryConfigurations()
//            .shuffled()
//        let testEntryConfigurations2 = TestEntryConfigurationFixtures()
//            .with(
//                buildArtifacts: .iosLogicTests(
//                    xcTestBundle: XcTestBundle(
//                        location: TestBundleLocation(.localFilePath("/2")),
//                        testDiscoveryMode: .parseFunctionSymbols
//                    )
//                )
//            )
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "test"))
//            .testEntryConfigurations()
//            .shuffled()
//        let mixedTestEntryConfigurations = [
//            testEntryConfigurations1[0],
//            testEntryConfigurations2[0],
//            testEntryConfigurations2[1],
//            testEntryConfigurations1[1],
//            testEntryConfigurations1[2]
//        ]
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: mixedTestEntryConfigurations)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 2)
//        XCTAssertEqual(groups[0], testEntryConfigurations1)
//        XCTAssertEqual(groups[1], testEntryConfigurations2)
//    }
//
//    func test___grouping_accounts_TestExecutionBehavior___preserves_order_and_sorts_by_test_count() {
//        let testEntryConfigurations1 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class3", methodName: "test"))
//            .testEntryConfigurations()
//            .shuffled()
//        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(testExecutionBehavior: TestExecutionBehavior(
//                environment: [:],
//                userInsertedLibraries: [],
//                numberOfRetries: 1,
//                testRetryMode: .retryThroughQueue,
//                logCapturingMode: .noLogs,
//                runnerWasteCleanupPolicy: .clean
//            ))
//            .testEntryConfigurations()
//        let mixedTestEntryConfigurations = [
//            testEntryConfiguration2[0],
//            testEntryConfigurations1[0],
//            testEntryConfigurations1[1],
//            testEntryConfigurations1[2]
//        ]
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: mixedTestEntryConfigurations)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 2)
//        XCTAssertEqual(groups[0], testEntryConfigurations1)
//        XCTAssertEqual(groups[1], testEntryConfiguration2)
//    }
//
//    func test___grouping_accounts_ToolchainConfiguration___preserves_order_and_sorts_by_test_count() {
//        let testEntryConfigurations1 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class3", methodName: "test"))
//            .testEntryConfigurations()
//            .shuffled()
//        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(developerDir: .useXcode(CFBundleShortVersionString: "10.2.1"))
//            .testEntryConfigurations()
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: testEntryConfiguration2 + testEntryConfigurations1)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 2)
//        XCTAssertEqual(groups[0], testEntryConfigurations1)
//        XCTAssertEqual(groups[1], testEntryConfiguration2)
//    }
//
//    func test___grouping_accounts_plugins___preserves_order_and_sorts_by_test_count() {
//        let testEntryConfigurations1 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "test"))
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class3", methodName: "test"))
//            .with(pluginLocations: [AppleTestPluginLocation(.localFilePath("plugin1"))])
//            .testEntryConfigurations()
//            .shuffled()
//        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(pluginLocations: [AppleTestPluginLocation(.localFilePath("plugin2"))])
//            .testEntryConfigurations()
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: testEntryConfiguration2 + testEntryConfigurations1)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 2)
//        XCTAssertEqual(groups[0], testEntryConfigurations1)
//        XCTAssertEqual(groups[1], testEntryConfiguration2)
//    }
//
//    func test___grouping_merges_tests_by_plugins() {
//        let testEntryConfiguration1 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test1"))
//            .with(pluginLocations: [AppleTestPluginLocation(.localFilePath("plugin1"))])
//            .testEntryConfigurations()
//        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test2"))
//            .with(pluginLocations: [AppleTestPluginLocation(.localFilePath("plugin2"))])
//            .testEntryConfigurations()
//        let testEntryConfiguration3 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test3"))
//            .with(pluginLocations: [AppleTestPluginLocation(.localFilePath("plugin1"))])
//            .testEntryConfigurations()
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: testEntryConfiguration1 + testEntryConfiguration2 + testEntryConfiguration3)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 2)
//        XCTAssertEqual(groups[0], testEntryConfiguration1 + testEntryConfiguration3)
//        XCTAssertEqual(groups[1], testEntryConfiguration2)
//    }
//
//    func test___grouping_mixed_entries___accounts_all_field_values() {
//        let testEntryConfiguration1 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(
//                buildArtifacts: .iosLogicTests(
//                    xcTestBundle: XcTestBundle(
//                        location: TestBundleLocation(.localFilePath("/2")),
//                        testDiscoveryMode: .parseFunctionSymbols
//                    )
//                )
//            )
//            .testEntryConfigurations()[0]
//        let testEntryConfiguration2 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(testExecutionBehavior: TestExecutionBehavior(
//                environment: [:],
//                userInsertedLibraries: [],
//                numberOfRetries: 1,
//                testRetryMode: .retryThroughQueue,
//                logCapturingMode: .noLogs,
//                runnerWasteCleanupPolicy: .clean
//            ))
//            .testEntryConfigurations()[0]
//        let testEntryConfiguration3 = TestEntryConfigurationFixtures()
//            .add(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "test"))
//            .with(simDeviceType: SimDeviceTypeFixture.fixture("device"))
//            .testEntryConfigurations()[0]
//
//        let mixedTestEntryConfigurations = [
//            testEntryConfiguration1,
//            testEntryConfiguration2,
//            testEntryConfiguration3
//        ]
//
//        let grouper = GroupedConfiguredTestEntry(testEntryConfigurations: mixedTestEntryConfigurations)
//        let groups = grouper.grouped()
//
//        XCTAssertEqual(groups.count, 3)
//        XCTAssertEqual(
//            Set<TestEntryConfiguration>(groups.flatMap { $0 }),
//            Set<TestEntryConfiguration>(mixedTestEntryConfigurations)
//        )
//    }
//
//    func test___grouping_same_test_entries_into_different_groups___with_one_class() {
//        let testEntry = TestEntryFixtures.testEntry(className: "class", methodName: "test")
//        let testEntryConfigurations = TestEntryConfigurationFixtures()
//            .with(simDeviceType: SimDeviceTypeFixture.fixture("device"))
//            .add(testEntry: testEntry)
//            .add(testEntry: testEntry)
//            .add(testEntry: testEntry)
//            .testEntryConfigurations()
//            .shuffled()
//
//        let groups = GroupedConfiguredTestEntry(
//            testEntryConfigurations: testEntryConfigurations
//        ).grouped()
//
//        XCTAssertEqual(groups.count, 3)
//        XCTAssertEqual(groups[0].count, 1)
//        XCTAssertEqual(groups[1].count, 1)
//        XCTAssertEqual(groups[2].count, 1)
//        XCTAssertEqual(groups[0][0].testEntry, testEntry)
//        XCTAssertEqual(groups[1][0].testEntry, testEntry)
//        XCTAssertEqual(groups[2][0].testEntry, testEntry)
//    }
//
//    func test___grouping_same_test_entries_into_different_groups___with_many_classes() {
//        let testEntry1 = TestEntryFixtures.testEntry(className: "class1", methodName: "test")
//        let testEntry2 = TestEntryFixtures.testEntry(className: "class2", methodName: "test")
//        let testEntry3 = TestEntryFixtures.testEntry(className: "class3", methodName: "test")
//        let testEntryConfigurations = TestEntryConfigurationFixtures()
//            .with(simDeviceType: SimDeviceTypeFixture.fixture("device"))
//            .add(testEntry: testEntry1)
//            .add(testEntry: testEntry1)
//            .add(testEntry: testEntry1)
//            .add(testEntry: testEntry2)
//            .add(testEntry: testEntry2)
//            .add(testEntry: testEntry2)
//            .add(testEntry: testEntry3)
//            .add(testEntry: testEntry3)
//            .add(testEntry: testEntry3)
//            .testEntryConfigurations()
//            .shuffled()
//        let expectedConfigurations = Set(
//            TestEntryConfigurationFixtures()
//            .with(simDeviceType: SimDeviceTypeFixture.fixture("device"))
//            .add(testEntry: testEntry1)
//            .add(testEntry: testEntry2)
//            .add(testEntry: testEntry3)
//            .testEntryConfigurations()
//            .shuffled()
//        )
//
//        let groups = GroupedConfiguredTestEntry(
//            testEntryConfigurations: testEntryConfigurations
//            ).grouped()
//
//        XCTAssertEqual(groups.count, 3)
//        XCTAssertEqual(groups[0].count, 3)
//        XCTAssertEqual(groups[1].count, 3)
//        XCTAssertEqual(groups[2].count, 3)
//        XCTAssertEqual(Set(groups[0]), expectedConfigurations)
//        XCTAssertEqual(Set(groups[1]), expectedConfigurations)
//        XCTAssertEqual(Set(groups[2]), expectedConfigurations)
//    }
}

