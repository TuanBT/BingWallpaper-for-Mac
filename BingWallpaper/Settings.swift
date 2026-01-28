import Foundation
import ServiceManagement

public class Settings {
    private let defaults = UserDefaults.standard
    private static let helperBundleId = "com.2h4u.BingWallpaperHelper"
    private static let SETTINGS_VERSION = "SETTINGS_VERSION"
    private static let CURRENT_SETTINGS_VERSION = 2  // Increment when breaking changes occur
    
    public init() {
        migrateSettingsIfNeeded()
    }
    
    /// Migrate settings from older versions
    private func migrateSettingsIfNeeded() {
        let version = defaults.integer(forKey: Settings.SETTINGS_VERSION)
        
        if version < 2 {
            // Version 2: Changed KeepImageDuration from [5,10,50,100,∞] to [1,2,5,10,∞]
            // Old values: 0=5, 1=10, 2=50, 3=100, 4=∞
            // New values: 0=1, 1=2, 2=5, 3=10, 4=∞
            // Map old to new: 0->2 (5 days), 1->3 (10 days), 2->2 (closest), 3->3 (closest), 4->4 (∞)
            if defaults.object(forKey: Settings.KEEP_IMAGE_DURATION) != nil {
                let oldValue = defaults.integer(forKey: Settings.KEEP_IMAGE_DURATION)
                let newValue: Int
                switch oldValue {
                case 0: newValue = 2  // 5 images -> 5 days
                case 1: newValue = 3  // 10 images -> 10 days
                case 2: newValue = 2  // 50 images -> 5 days (closest)
                case 3: newValue = 3  // 100 images -> 10 days (closest)
                case 4: newValue = 4  // infinite -> infinite
                default: newValue = 2 // default to 5 days
                }
                defaults.set(newValue, forKey: Settings.KEEP_IMAGE_DURATION)
            }
        }
        
        defaults.set(Settings.CURRENT_SETTINGS_VERSION, forKey: Settings.SETTINGS_VERSION)
    }
    
    var launchAtLogin: Bool {
        get {
            // For macOS 13+, check SMAppService status
            if #available(macOS 13.0, *) {
                let service = SMAppService.loginItem(identifier: Settings.helperBundleId)
                return service.status == .enabled
            } else {
                return defaults.bool(forKey: Settings.SM_LOGIN_ENABLED)
            }
        }
        set {
            if #available(macOS 13.0, *) {
                let service = SMAppService.loginItem(identifier: Settings.helperBundleId)
                do {
                    if newValue {
                        try service.register()
                    } else {
                        try service.unregister()
                    }
                } catch {
                    print("Failed to \(newValue ? "register" : "unregister") login item: \(error)")
                }
            } else {
                SMLoginItemSetEnabled(Settings.helperBundleId as CFString, newValue)
            }
            defaults.set(newValue, forKey: Settings.SM_LOGIN_ENABLED)
        }
    }
    
    var hideMenuBarIcon: Bool {
        get {
            return defaults.bool(forKey: Settings.HIDE_MENU_BAR_ICON)
        }
        set {
            defaults.set(newValue, forKey: Settings.HIDE_MENU_BAR_ICON)
        }
    }
    
    var imageDownloadPath: URL {
        get {
            return defaults.url(forKey: Settings.IMAGE_DOWNLOAD_PATH) ?? FileHandler.defaultBingWallpaperDirectory()
        }
        set {
            defaults.set(newValue, forKey: Settings.IMAGE_DOWNLOAD_PATH)
        }
    }
    
    public var lastUpdate: Date {
        get {
            return defaults.object(forKey: Settings.LAST_UPDATE) as? Date ?? Date.distantPast
        }
        set {
            defaults.set(newValue, forKey: Settings.LAST_UPDATE)
        }
    }
    
    var keepImageDuration: Int {
        get {
            return defaults.object(forKey: Settings.KEEP_IMAGE_DURATION) as? Int ?? KeepImageDuration.five.rawValue
        }
        set {
            defaults.set(newValue, forKey: Settings.KEEP_IMAGE_DURATION)
        }
    }
    
    var updateIntervalHours: Double {
        get {
            return defaults.object(forKey: Settings.UPDATE_INTERVAL_HOURS) as? Double ?? 3.0
        }
        set {
            defaults.set(newValue, forKey: Settings.UPDATE_INTERVAL_HOURS)
        }
    }
    
    var marketRegion: String {
        get {
            return defaults.string(forKey: Settings.MARKET_REGION) ?? "en-US"
        }
        set {
            defaults.set(newValue, forKey: Settings.MARKET_REGION)
        }
    }
    
    var useScheduledUpdate: Bool {
        get {
            return defaults.bool(forKey: Settings.USE_SCHEDULED_UPDATE)
        }
        set {
            defaults.set(newValue, forKey: Settings.USE_SCHEDULED_UPDATE)
        }
    }
    
    var scheduledUpdateHour: Int {
        get {
            return defaults.object(forKey: Settings.SCHEDULED_UPDATE_HOUR) as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: Settings.SCHEDULED_UPDATE_HOUR)
        }
    }
    
    var scheduledUpdateMinute: Int {
        get {
            return defaults.object(forKey: Settings.SCHEDULED_UPDATE_MINUTE) as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: Settings.SCHEDULED_UPDATE_MINUTE)
        }
    }
    
    private func keepImageTimeInterval() -> TimeInterval? {
        let durationInDays: Double?
        
        switch keepImageDuration {
        case KeepImageDuration.one.rawValue:
            durationInDays = 1
        case KeepImageDuration.two.rawValue:
            durationInDays = 2
        case KeepImageDuration.five.rawValue:
            durationInDays = 5
        case KeepImageDuration.ten.rawValue:
            durationInDays = 10
        case KeepImageDuration.infinite.rawValue:
            durationInDays = nil
        default:
            durationInDays = 5 // Default to 5 days
        }
        
        guard let durationInDays = durationInDays else {
            return nil
        }
        
        return durationInDays * 3600.0 * 24.0
    }
    
    func oldestDateToKeep() -> Date? {
        guard let keepImageTimeInterval = keepImageTimeInterval() else {
            return nil
        }
        return Date().addingTimeInterval(-keepImageTimeInterval)
    }
    
    func oldestDateStringToKeep() -> String? {
        guard let oldestDateToKeep = oldestDateToKeep() else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter.string(from: oldestDateToKeep)
    }
    
    private static let SM_LOGIN_ENABLED = "SM_LOGIN_ENABLED"
    private static let HIDE_MENU_BAR_ICON = "HIDE_MENU_BAR_ICON"
    private static let IMAGE_DOWNLOAD_PATH = "IMAGE_DOWNLOAD_PATH"
    private static let LAST_UPDATE = "LAST_UPDATE"
    private static let KEEP_IMAGE_DURATION = "KEEP_IMAGE_DURATION"
    private static let UPDATE_INTERVAL_HOURS = "UPDATE_INTERVAL_HOURS"
    private static let MARKET_REGION = "MARKET_REGION"
    private static let USE_SCHEDULED_UPDATE = "USE_SCHEDULED_UPDATE"
    private static let SCHEDULED_UPDATE_HOUR = "SCHEDULED_UPDATE_HOUR"
    private static let SCHEDULED_UPDATE_MINUTE = "SCHEDULED_UPDATE_MINUTE"
}
