//
//  AppUpdateManager.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 11.12.22.
//

import Foundation
import AppKit

class AppUpdateManager {
    
    private static let githubLatestReleaseUrl = URL(string: "https://github.com/TuanBT/BingWallpaper-for-Mac/releases/latest")!
    
    static func currentAppVersion() -> String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    static func fetchLatestAppVersionFromGithub() async -> String? {
        let latestHtmlHeaders = await DownloadManager.downloadHtmlHeaders(from: githubLatestReleaseUrl)
        return latestHtmlHeaders?.url?.lastPathComponent
    }
    
    private static func newVersionAvailable(_ currentAppVersion: String, _ latestAppVersion: String) -> Bool {
        let currentAppVersion = currentAppVersion.replacingOccurrences(of: "v", with: "")
        let latestAppVersion = latestAppVersion.replacingOccurrences(of: "v", with: "")
        return currentAppVersion.versionCompare(latestAppVersion) == .orderedAscending
    }
    
    static func checkForUpdate(notifyUserAboutNoNewVersion:Bool = false) async {
        guard let latestGithubAppVersion = await fetchLatestAppVersionFromGithub() else {
            print("Failed to fetch latest app version from github")
            await showErrorDialog(message: "Failed to check for updates. Please check your internet connection.")
            return
        }
        
        let currentAppVersion = currentAppVersion()
        
        if newVersionAvailable(currentAppVersion, latestGithubAppVersion) == false {
            print("No app update requiered, \(currentAppVersion) is alread the newest version")
            
            if notifyUserAboutNoNewVersion == true {
                    await showAlreadyUpToDateDialog()
            }
            return
        }
        
        // Show dialog with option to open GitHub release page
        if await showNewVersionAvailableDialog(currentAppVersion: currentAppVersion, latestAppVersion: latestGithubAppVersion) == true {
            // User clicked "Download" - open GitHub release page in browser
            var releaseUrl = URL(string: "https://github.com/TuanBT/BingWallpaper-for-Mac/releases/tag/")!
            releaseUrl.appendPathComponent(latestGithubAppVersion)
            NSWorkspace.shared.open(releaseUrl)
        }
    }
    
    @MainActor
    private static func showNewVersionAvailableDialog(currentAppVersion: String, latestAppVersion: String) -> Bool {
        let currentAppVersion = currentAppVersion.replacingOccurrences(of: "v", with: "")
        let latestAppVersion = latestAppVersion.replacingOccurrences(of: "v", with: "")
        let alert = NSAlert()
        alert.messageText = "New version of BingWallpaper available"
        alert.informativeText = """
        A new version is available for download!
        
        Current version: \(currentAppVersion)
        New version: \(latestAppVersion)
        
        Click "Download" to open the GitHub release page.
        """
        let downloadButton = alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        
        alert.window.defaultButtonCell = downloadButton.cell as? NSButtonCell
        
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
    
    @MainActor
    private static func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    @MainActor
    private static func showAlreadyUpToDateDialog() {
        let alert = NSAlert()
        alert.messageText = "BingWallpaper already up to date"
        alert.informativeText = "There is no new version of BingWallpaper available"
        let updateButton = alert.addButton(withTitle: "Ok")
        alert.alertStyle = .informational
        
        alert.window.defaultButtonCell = updateButton.cell as? NSButtonCell
        
        alert.runModal()
    }
    
}
