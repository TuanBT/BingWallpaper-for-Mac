import Foundation
import AppKit
import UserNotifications
import Network

protocol UpdateManagerDelegate: AnyObject {
    @MainActor
    func downloadedNewImage()
    @MainActor
    func updateStatusChanged(nextUpdate: Date?, isUpdating: Bool)
}

// Make delegate methods optional with default implementations
extension UpdateManagerDelegate {
    func updateStatusChanged(nextUpdate: Date?, isUpdating: Bool) {}
}

class UpdateManager {
    weak var delegate: UpdateManagerDelegate?
    private let settings = Settings()
    private var dispatchTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.bingwallpaper.timer", qos: .utility)
    
    // Retry configuration
    private var retryCount = 0
    private let maxRetries = 3
    private let retryDelaySeconds: TimeInterval = 60 // Retry after 1 minute
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    // State tracking
    private(set) var isUpdating = false
    private(set) var nextUpdateTime: Date?
    
    deinit {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        networkMonitor.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @MainActor
    func start() {
        setupObserver()
        setupNetworkMonitor()
        requestNotificationPermission()
        doUpdateOrSetTimer()
    }
    
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let wasAvailable = self?.isNetworkAvailable ?? true
            self?.isNetworkAvailable = path.status == .satisfied
            
            // If network just became available and we have pending retries, try again
            if !wasAvailable && path.status == .satisfied {
                print("[Network] Network became available, checking for pending updates")
                Task { @MainActor [weak self] in
                    self?.doUpdateOrSetTimer()
                }
            }
        }
        networkMonitor.start(queue: timerQueue)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("[Notification] Permission granted")
            } else if let error = error {
                print("[Notification] Permission error: \(error)")
            }
        }
    }
    
    @MainActor
    private func doUpdateOrSetTimer() {
        // Check network availability first
        guard isNetworkAvailable else {
            print("[Update] Network not available, waiting for connection...")
            return
        }
        
        if UpdateScheduleManager.isUpdateNecessary() {
            update()
            return
        }
        
        let nextFetchInterval = UpdateScheduleManager.nextFetchTimeInterval()
        scheduleTimerWithInterval(nextFetchInterval)
    }
    
    private func scheduleTimerWithInterval(_ interval: TimeInterval) {
        let nextTime = Date().addingTimeInterval(interval)
        nextUpdateTime = nextTime
        
        print("[Timer] Next update scheduled at \(nextTime) (in \(Int(interval)) seconds)")
        
        // Notify delegate about status change
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.updateStatusChanged(nextUpdate: nextTime, isUpdating: false)
        }
        
        // Cancel existing timer
        dispatchTimer?.cancel()
        
        // Create new DispatchSourceTimer for more reliable timing
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer.schedule(deadline: .now() + interval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }
        timer.resume()
        dispatchTimer = timer
    }
    
    @MainActor
    private func cleanup() {
        // TODO: @2h4u: find entries with same startDate and remove them
        // TODO: @2h4u: probably do this in a migration function in appdelegate
        
        guard let oldestDateStringToKeep = settings.oldestDateStringToKeep() else { return }
        try? Database.instance.deleteImageDescriptors(olderThan: oldestDateStringToKeep)
        FileHandler.deleteOldImages(oldestDateStringToKeep: oldestDateStringToKeep)
    }
    
    private func setupObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receiveSleepNote),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receiveWakeNote),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @MainActor
    @objc func update() {
        // Prevent concurrent updates
        guard !isUpdating else { return }
        
        // Check network availability
        guard isNetworkAvailable else { return }
        
        isUpdating = true
        delegate?.updateStatusChanged(nextUpdate: nil, isUpdating: true)
        
        settings.lastUpdate = Date()
        
        Task { [weak self] in
            guard let self = self else { return }
            
            let imageEntries: [DownloadManager.ImageEntry]
            do {
                imageEntries = try await DownloadManager.downloadImageEntries(numberOfImages: 8, market: self.settings.marketRegion)
                // Reset retry count on success
                self.retryCount = 0
            } catch {
                self.handleUpdateFailure()
                return
            }
            
            let descriptors = Database.instance.updateImageDescriptors(from: imageEntries)
            
            let newDescriptors = descriptors
                .filter { $0.image.isOnDisk() == false }
            
            var downloadedCount = 0
            for descriptor in newDescriptors {
                do {
                    try await descriptor.image.downloadAndSaveToDisk()
                    downloadedCount += 1
                } catch {
                    // Skip failed images silently
                }
            }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isUpdating = false
                self.cleanup()
                
                // Notify delegate about new images (for UI update)
                if newDescriptors.isEmpty == false {
                    self.delegate?.downloadedNewImage()
                }
                
                // Auto-set newest wallpaper if enabled (and there are any images)
                if self.settings.autoSetNewestWallpaper {
                    self.setNewestWallpaperAutomatically()
                }
                
                // Show notification if new images were downloaded
                if downloadedCount > 0 && self.settings.showUpdateNotification {
                    self.showWallpaperUpdateNotification(count: downloadedCount)
                }
                
                self.scheduleNextUpdate()
            }
        }
    }
    
    @MainActor
    private func handleUpdateFailure() {
        isUpdating = false
        retryCount += 1
        
        if retryCount <= maxRetries {
            scheduleTimerWithInterval(retryDelaySeconds)
        } else {
            retryCount = 0
            scheduleNextUpdate()
        }
    }
    
    @MainActor
    private func scheduleNextUpdate() {
        let fetchInterval = UpdateScheduleManager.nextFetchTimeInterval()
        scheduleTimerWithInterval(fetchInterval)
    }
    
    private func showWallpaperUpdateNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Bing Wallpaper Updated"
        content.body = count == 1 
            ? "A new wallpaper has been downloaded and set."
            : "\(count) new wallpapers have been downloaded."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "wallpaper-update", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    @MainActor
    @objc func receiveSleepNote(note: NSNotification) {
        dispatchTimer?.suspend()
    }
    
    @MainActor
    @objc func receiveWakeNote(note: NSNotification) {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        doUpdateOrSetTimer()
    }
    
    @MainActor
    func reschedule() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        doUpdateOrSetTimer()
    }
    
    /// Force refresh - called when user clicks refresh button
    @MainActor
    func forceRefresh() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        retryCount = 0
        update()
    }
    
    /// Automatically set the newest available wallpaper
    @MainActor
    private func setNewestWallpaperAutomatically() {
        let descriptors = Database.instance.allImageDescriptors()
            .filter { $0.image.isOnDisk() }
        
        guard let newestDescriptor = descriptors.last else { return }
        
        // Save selected wallpaper to settings
        settings.currentWallpaperStartDate = newestDescriptor.startDate
        
        WallpaperManager.shared.setWallpaper(descriptor: newestDescriptor)
    }
    
    /// Restore last selected wallpaper on app start
    @MainActor
    func restoreLastWallpaper() {
        guard let savedStartDate = settings.currentWallpaperStartDate else { return }
        
        let descriptors = Database.instance.allImageDescriptors()
            .filter { $0.image.isOnDisk() }
        
        if let savedDescriptor = descriptors.first(where: { $0.startDate == savedStartDate }) {
            WallpaperManager.shared.setWallpaper(descriptor: savedDescriptor)
        }
    }
}
