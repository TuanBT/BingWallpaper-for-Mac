import AppKit
import Foundation

class WallpaperManager {
    private var imageDescriptor: ImageDescriptor?
    static let shared = WallpaperManager()
    private var hasAppleScriptPermission = true // Assume yes, will be set to false if it fails
    private var lastSetWallpaperPath: String? // Track to avoid redundant sets
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        // Only observe space change if we don't have AppleScript permission
        // This avoids redundant wallpaper sets when AppleScript already handles all spaces
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.activeWorkspaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Observe when system wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Observe when screens change (connect/disconnect monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WallpaperManager.screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc func activeWorkspaceDidChange() {
        // Only apply wallpaper when switching space if AppleScript failed
        // (AppleScript already sets all spaces at once)
        guard !hasAppleScriptPermission else { return }
        updateWallpaperIfNeeded(forceNSWorkspace: true)
    }
    
    @objc func workspaceDidWake() {
        // Re-apply wallpaper after wake from sleep
        updateWallpaperIfNeeded(forceNSWorkspace: false)
    }
    
    @objc func screensDidChange() {
        // Apply wallpaper when monitors are connected/disconnected
        updateWallpaperIfNeeded(forceNSWorkspace: false)
    }
    
    func setWallpaper(descriptor: ImageDescriptor) {
        imageDescriptor = descriptor
        
        // Save selection to settings for persistence
        Settings().currentWallpaperStartDate = descriptor.startDate
        
        // Reset last set path to force update
        lastSetWallpaperPath = nil
        updateWallpaperIfNeeded(forceNSWorkspace: false)
    }
    
    private func updateWallpaperIfNeeded(forceNSWorkspace: Bool) {
        guard let descriptor = imageDescriptor else { return }
        let imageUrl = descriptor.image.downloadPath
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: imageUrl.path) else { return }
        
        // Skip if same wallpaper was just set (avoid redundant operations)
        if !forceNSWorkspace && lastSetWallpaperPath == imageUrl.path {
            return
        }
        
        // Try AppleScript first to set wallpaper for ALL spaces and screens
        if !forceNSWorkspace && hasAppleScriptPermission && setWallpaperViaAppleScript(imageUrl: imageUrl) {
            lastSetWallpaperPath = imageUrl.path
            return
        }
        
        // Fallback: NSWorkspace API - only sets CURRENT space on each screen
        setWallpaperViaNSWorkspace(imageUrl: imageUrl)
        lastSetWallpaperPath = imageUrl.path
    }
    
    /// Use AppleScript to set wallpaper for ALL desktops (spaces) and screens
    /// This requires Automation permission for System Events
    private func setWallpaperViaAppleScript(imageUrl: URL) -> Bool {
        let imagePath = imageUrl.path
        
        // AppleScript to set wallpaper for all desktops (spaces) and all screens
        let script = """
        tell application "System Events"
            tell every desktop
                set picture to "\(imagePath)"
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                let errorNumber = error["NSAppleScriptErrorNumber"] as? Int ?? 0
                
                // Error -1743: User hasn't granted permission
                // Error -600: Application not running
                if errorNumber == -1743 || errorNumber == -600 {
                    hasAppleScriptPermission = false
                }
                return false
            }
            
            return true
        }
        
        return false
    }
    
    /// Fallback: Use NSWorkspace API to set wallpaper
    /// NOTE: This only sets wallpaper for the CURRENT space on each screen
    private func setWallpaperViaNSWorkspace(imageUrl: URL) {
        let workspace = NSWorkspace.shared
        
        for screen in NSScreen.screens {
            try? workspace.setDesktopImageURL(imageUrl, for: screen, options: [:])
        }
    }
}
