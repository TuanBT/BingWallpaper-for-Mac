import AppKit
import Foundation

class WallpaperManager {
    private var imageDescriptor: ImageDescriptor?
    static let shared = WallpaperManager()
    private var hasAppleScriptPermission = true // Assume yes, will be set to false if it fails
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        // Observe space changes to re-apply wallpaper on the new space
        // NSWorkspace API only sets the CURRENT space, so we must re-apply each time
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
        // Always re-apply wallpaper when switching spaces
        // NSWorkspace only sets the current space, so each space switch needs re-application
        applyWallpaper()
    }
    
    @objc func workspaceDidWake() {
        // Re-apply wallpaper after wake from sleep with a delay
        // macOS may reset or lose wallpaper state during sleep/wake cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.applyWallpaper()
        }
    }
    
    @objc func screensDidChange() {
        // Apply wallpaper when monitors are connected/disconnected
        // Use a delay to allow macOS to finish configuring the new screen layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.applyWallpaper()
        }
    }
    
    func setWallpaper(descriptor: ImageDescriptor) {
        imageDescriptor = descriptor
        
        // Save selection to settings for persistence
        Settings().currentWallpaperStartDate = descriptor.startDate
        
        applyWallpaper()
    }
    
    /// Core method: applies the current wallpaper using all available methods
    private func applyWallpaper() {
        guard let descriptor = imageDescriptor else { return }
        let imageUrl = descriptor.image.downloadPath
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: imageUrl.path) else {
            print("[Wallpaper] Image file not found at: \(imageUrl.path)")
            return
        }
        
        // 1. Always use NSWorkspace as primary method (most reliable on modern macOS)
        setWallpaperViaNSWorkspace(imageUrl: imageUrl)
        
        // 2. Additionally try AppleScript for all-spaces support
        //    This sets wallpaper on spaces that are not currently active
        if hasAppleScriptPermission {
            _ = setWallpaperViaAppleScript(imageUrl: imageUrl)
        }
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
                print("[Wallpaper] AppleScript error \(errorNumber): \(error)")
                
                // Error -1743: User hasn't granted permission
                // Error -600: Application not running
                if errorNumber == -1743 || errorNumber == -600 {
                    hasAppleScriptPermission = false
                    print("[Wallpaper] AppleScript permission denied, will not try again")
                }
                return false
            }
            
            return true
        }
        
        return false
    }
    
    /// Use NSWorkspace API to set wallpaper for CURRENT space on each screen
    private func setWallpaperViaNSWorkspace(imageUrl: URL) {
        let workspace = NSWorkspace.shared
        
        for screen in NSScreen.screens {
            do {
                // Preserve existing wallpaper display options (scaling, fill color, etc.)
                // so we only change the image, not the user's display preferences
                var options = workspace.desktopImageOptions(for: screen) ?? [:]
                
                // Ensure reasonable defaults if no options exist
                if options.isEmpty {
                    options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
                    options[.allowClipping] = true
                }
                
                try workspace.setDesktopImageURL(imageUrl, for: screen, options: options)
            } catch {
                print("[Wallpaper] Failed to set wallpaper for screen \(screen.localizedName): \(error)")
                // Retry with default options as fallback
                try? workspace.setDesktopImageURL(imageUrl, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true
                ])
            }
        }
    }
}
