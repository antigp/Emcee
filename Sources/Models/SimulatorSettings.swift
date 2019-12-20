import Foundation

public struct SimulatorSettings: Codable, Hashable, CustomStringConvertible {
    /// Location of JSON file with localization settings for Simulator.
    /// These settings will be applied with fbxctest start in simulator.
    public let simulatorLocalizationSettings: SimulatorLocalizationLocation?

    /// Location of  .GlobalPreferences.plist.
    /// These settings will be applied after simulator has been created and before it will be booted.
    public let preBootGlobalPreference: PreBootGlobalPreferenceLocation?
    
    /** Absolute path to JSON with watchdog settings for Simulator. */
    public let watchdogSettings: WatchdogSettingsLocation?

    public init(
        simulatorLocalizationSettings: SimulatorLocalizationLocation?,
        watchdogSettings: WatchdogSettingsLocation?,
        preBootGlobalPreference: PreBootGlobalPreferenceLocation?
        )
    {
        self.simulatorLocalizationSettings = simulatorLocalizationSettings
        self.watchdogSettings = watchdogSettings
        self.preBootGlobalPreference = preBootGlobalPreference
    }
    
    public var description: String {
        let localization = String(describing: simulatorLocalizationSettings)
        let watchdog = String(describing: watchdogSettings)
        return "<\((type(of: self))): localization: \(localization), watchdogSettings: \(watchdog)>"
    }
}
