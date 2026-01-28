import AppKit
import Foundation

class WallpaperManager {
    private var imageDescriptor: ImageDescriptor?
    static let shared = WallpaperManager()
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.activeWorkspaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc func activeWorkspaceDidChange() {
        updateWallpaperIfNeeded()
    }
    
    @objc func workspaceDidWake() {
        updateWallpaperIfNeeded()
    }
    
    func setWallpaper(descriptor: ImageDescriptor) {
        imageDescriptor = descriptor
        updateWallpaperIfNeeded()
    }
    
    private func updateWallpaperIfNeeded() {
        guard let descriptor = imageDescriptor else { return }
        let imageUrl = descriptor.image.downloadPath
        
        // Try AppleScript first to set wallpaper for all spaces and screens
        if setWallpaperViaAppleScript(imageUrl: imageUrl) {
            print("✅ Set wallpaper for all spaces via AppleScript")
            return
        }
        
        // Fallback to NSWorkspace API (only sets current space)
        print("⚠️ AppleScript failed, falling back to NSWorkspace API")
        let workspace = NSWorkspace.shared
        
        do {
            for screen in NSScreen.screens {
                try workspace.setDesktopImageURL(imageUrl, for: screen, options: [:])
            }
        } catch {
            print("❌ Failed to set wallpaper: \(error)")
        }
    }
    
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
                print("❌ AppleScript error: \(error)")
                return false
            }
            
            return true
        }
        
        return false
    }
}
