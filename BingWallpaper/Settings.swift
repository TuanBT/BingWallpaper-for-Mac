import Foundation
import ServiceManagement

public class Settings {
    private let defaults = UserDefaults.standard
    
    public init() { }
    
    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: Settings.SM_LOGIN_ENABLED)
        }
        set {
            SMLoginItemSetEnabled("com.2h4u.BingWallpaperHelper" as CFString, newValue)
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
            return defaults.object(forKey: Settings.KEEP_IMAGE_DURATION) as? Int ?? KeepImageDuration.fifty.rawValue
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
        case KeepImageDuration.five.rawValue:
            durationInDays = 5
        case KeepImageDuration.ten.rawValue:
            durationInDays = 10
        case KeepImageDuration.fifty.rawValue:
            durationInDays = 50
        case KeepImageDuration.onehundred.rawValue:
            durationInDays = 100
        case KeepImageDuration.infinite.rawValue:
            durationInDays = nil
        default:
            durationInDays = 50
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
