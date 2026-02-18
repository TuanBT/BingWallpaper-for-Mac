import AppKit
import Foundation

class WallpaperManager {
    private var imageDescriptor: ImageDescriptor?
    private var directImageUrl: URL?  // For region preview wallpapers (no descriptor)
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
        // Re-apply wallpaper when switching spaces using only NSWorkspace (fast path).
        // AppleScript is intentionally skipped here: it is slow (~100–500 ms) and
        // causes a noticeable delay / extra re-render on every space transition.
        // AppleScript is called once when the wallpaper is first set (setWallpaper methods)
        // to cover all spaces; NSWorkspace is enough to fix the current active space.
        applyWallpaper(updateAllSpaces: false)
    }
    
    @objc func workspaceDidWake() {
        // Re-apply wallpaper after wake from sleep with a delay.
        // Use full update (all spaces) since macOS may have reset wallpapers on all spaces.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.applyWallpaper(updateAllSpaces: true)
        }
    }

    @objc func screensDidChange() {
        // Apply wallpaper when monitors are connected/disconnected.
        // Use full update (all spaces) for the new screen layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.applyWallpaper(updateAllSpaces: true)
        }
    }
    
    func setWallpaper(descriptor: ImageDescriptor) {
        imageDescriptor = descriptor
        directImageUrl = nil  // Clear any region preview
        
        // Save selection to settings for persistence
        Settings().currentWallpaperStartDate = descriptor.startDate
        
        applyWallpaper(updateAllSpaces: true)
    }
    
    /// Set wallpaper directly from an image file URL (e.g., region preview)
    /// The wallpaper will persist until the next scheduled update replaces it.
    func setWallpaper(imageUrl: URL) {
        guard FileManager.default.fileExists(atPath: imageUrl.path) else {
            print("[Wallpaper] Image file not found at: \(imageUrl.path)")
            return
        }
        
        // Store the direct URL for re-application on space changes
        directImageUrl = imageUrl
        imageDescriptor = nil
        Settings().currentWallpaperStartDate = nil
        
        // Apply to all spaces so that switching spaces doesn't flash the old wallpaper
        applyWallpaper(updateAllSpaces: true)
    }
    
    /// Core method: applies the current wallpaper.
    /// - Parameter updateAllSpaces: When `true`, also invokes AppleScript to update
    ///   every desktop/space in addition to the current one via NSWorkspace.
    ///   Pass `false` on hot-path calls (e.g. space-change observer) to avoid the
    ///   ~100–500 ms AppleScript overhead that would otherwise cause a visible re-render
    ///   flicker on each space transition.
    private func applyWallpaper(updateAllSpaces: Bool) {
        let imageUrl: URL
        
        if let directUrl = directImageUrl,
           FileManager.default.fileExists(atPath: directUrl.path) {
            // Use direct URL (region preview)
            imageUrl = directUrl
        } else if let descriptor = imageDescriptor {
            // Use descriptor-based path
            imageUrl = descriptor.image.downloadPath
            guard FileManager.default.fileExists(atPath: imageUrl.path) else {
                print("[Wallpaper] Image file not found at: \(imageUrl.path)")
                return
            }
        } else {
            return
        }
        
        // 1. Always use NSWorkspace as primary method (most reliable on modern macOS).
        //    This updates only the CURRENT active space.
        setWallpaperViaNSWorkspace(imageUrl: imageUrl)
        
        // 2. Optionally use AppleScript to set wallpaper on ALL spaces/desktops.
        //    This is intentionally skipped on space-change events (updateAllSpaces == false)
        //    because AppleScript is synchronous and slow, which causes a secondary
        //    flicker/re-render visible to the user on every swipe between desktops.
        if updateAllSpaces && hasAppleScriptPermission {
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
