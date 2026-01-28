import Cocoa
import ObjectiveC

class MenuController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let settings = Settings()
    private var descriptors = [ImageDescriptor]()
    private var selectedDescriptorIndex = 0
    private var imageSelectorView: ImageSelectorView!
    var updateManager: UpdateManager?
    private static let IMAGE_VIEW_TAG = 6
    private static let TEXT_VIEW_TAG = 7
    private static let REGION_SUBMENU_TAG = 8
    private lazy var settingsWc = SettingsWc.instance()
    
    // Current preview region (different from download region in settings)
    private var previewRegion: String?
    private var isLoadingRegionPreview = false
    
    // MARK: - UI setup
    
    @MainActor
    func setup() {
        guard self.statusItem == nil && self.menu == nil else { return }
        if settings.hideMenuBarIcon == true { return }
        
        self.statusItem = createStatusBarItem()
        self.menu = createMenu()
        self.statusItem!.menu = menu
        
        showNewestImage()
    }
    
    private func createStatusBarItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "BingWallpaper")
        }
        
        return statusItem
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.minimumWidth = 300
        
        let imageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        imageSelectorView = ImageSelectorView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: imageSelectorViewHeight(menu: menu)))
        imageSelectorView.leftButton.action = #selector(MenuController.imageSelectorViewLeftButtonAction)
        imageSelectorView.leftButton.target = self
        imageSelectorView.rightButton.action = #selector(MenuController.imageSelectorViewRightButtonAction)
        imageSelectorView.rightButton.target = self
        imageItem.view = imageSelectorView
        imageItem.tag = MenuController.IMAGE_VIEW_TAG
        menu.addItem(imageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "Refresh Images", action: #selector(refreshImages), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // Add "Browse Other Regions" submenu
        let browseRegionsItem = NSMenuItem(title: "Browse Other Regions", action: nil, keyEquivalent: "")
        browseRegionsItem.tag = MenuController.REGION_SUBMENU_TAG
        let regionsSubmenu = createRegionsSubmenu()
        browseRegionsItem.submenu = regionsSubmenu
        menu.addItem(browseRegionsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let appUpdateItem = NSMenuItem(title: "Check for app update", action: #selector(checkForAppUpdate), keyEquivalent: "")
        appUpdateItem.target = self
        menu.addItem(appUpdateItem)
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettingsWc), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    // MARK: - IBActions
    
    @MainActor
    @objc func showSettingsWc(sender: NSMenuItem?) {
        (settingsWc.contentViewController as! SettingsVc).delegate = self
        (settingsWc.contentViewController as! SettingsVc).updateManager = updateManager
        settingsWc.showWindow(self)
        settingsWc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    @objc func refreshImages(sender: NSMenuItem) {
        updateManager?.update()
    }
    
    @MainActor
    @objc func checkForAppUpdate(sender: NSMenuItem) {
        Task {
            await AppUpdateManager.checkForUpdate()
        }
    }
    
    @MainActor
    @objc func imageSelectorViewLeftButtonAction(_ sender: NSButton) {
        if descriptors.indices.contains(selectedDescriptorIndex - 1) == false {
            return
        }
        
        selectedDescriptorIndex = selectedDescriptorIndex - 1
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    @MainActor
    @objc func imageSelectorViewRightButtonAction(_ sender: NSButton) {
        if descriptors.indices.contains(selectedDescriptorIndex + 1) == false {
            return
        }
        
        selectedDescriptorIndex = selectedDescriptorIndex + 1
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    @MainActor
    @objc func textItemAction(sender: NSMenuItem) {
        if let descriptor = descriptors[safe: selectedDescriptorIndex] {
            NSWorkspace.shared.open(descriptor.copyrightUrl)
        }
    }
    
    // MARK: - Helper
    
    private func imageSelectorViewHeight(menu: NSMenu) -> CGFloat {
        let outerPadding = 5.0
        let buttonWidth = 15.0
        let innerPadding = 5.0
        let imageViewWidth = menu.size.width - outerPadding*2 - buttonWidth*2 - innerPadding*2
        let topMargin = 4.0
        return imageViewWidth / 16*9 + topMargin
    }
    
    private func updateSelectedImage(newSelectedDescriptorIndex: Int) {
        if let descriptor = descriptors[safe: newSelectedDescriptorIndex] {
            WallpaperManager.shared.setWallpaper(descriptor: descriptor)
        }
    }
    
    @MainActor
    private func updateImageSelectorView(newSelectedDescriptorIndex: Int) {
        guard let menu = menu else { return }
        
        let descriptor = descriptors[safe: newSelectedDescriptorIndex]
        Task {
            guard let descriptor else { return }
            do {
                let imageData = try await descriptor.image.loadFromDisk()
                await MainActor.run { [weak self] in
                    self?.imageSelectorView.imageView.image = NSImage(data: imageData)
                }
            } catch {
                print("Failed to load image from disk: \(descriptor)")
            }
        }
        
        let textItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        textItem.tag = MenuController.TEXT_VIEW_TAG
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: 0))
        textView.descriptionLabel.stringValue = getDescription(description: descriptor?.descriptionString)
        textView.copyrightLabel.stringValue = getCopyright(description: descriptor?.descriptionString)
        textView.button.action = #selector(textItemAction)
        textView.button.target = self
        textItem.view = textView
        
        if let oldTextItem = menu.item(withTag: MenuController.TEXT_VIEW_TAG) {
            menu.removeItem(oldTextItem)
        }
        let imageView = menu.item(withTag: MenuController.IMAGE_VIEW_TAG)!
        let textViewIndex = menu.index(of: imageView) + 1
        menu.insertItem(textItem, at: textViewIndex)
        
        imageSelectorView.leftButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex - 1)
        imageSelectorView.rightButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex + 1)
    }
    
    private func getDescription(description: String?) -> String {
        if description == nil { return "" }
        return String(description?.split(separator: "(").first ?? "")
    }
    
    private func getCopyright(description: String?) -> String {
        if description == nil { return "" }
        return description?.split(separator: "(").last?.replacingOccurrences(of: ")", with: "") ?? ""
    }
    
    @MainActor
    private func showNewestImage() {
        self.descriptors = Database.instance.allImageDescriptors()
            .filter { $0.image.isOnDisk() }
        selectedDescriptorIndex = self.descriptors.firstIndex(where: { $0 == self.descriptors.last }) ?? self.descriptors.endIndex
        previewRegion = nil // Reset to default region
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    // MARK: - Region Browsing
    
    private func createRegionsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        
        // Add "Back to My Region" item
        let backItem = NSMenuItem(title: "⬅️ Back to My Region (\(settings.marketRegion))", action: #selector(backToMyRegion), keyEquivalent: "")
        backItem.target = self
        backItem.representedObject = "BACK_TO_MY_REGION"
        submenu.addItem(backItem)
        
        submenu.addItem(NSMenuItem.separator())
        
        // Add popular regions section
        let popularHeader = NSMenuItem(title: "Popular Regions", action: nil, keyEquivalent: "")
        popularHeader.isEnabled = false
        submenu.addItem(popularHeader)
        
        for region in MarketRegion.popularRegions {
            let item = NSMenuItem(title: region.displayName, action: #selector(previewRegionSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = region.code
            submenu.addItem(item)
        }
        
        submenu.addItem(NSMenuItem.separator())
        
        // Add "All Regions" submenu
        let allRegionsItem = NSMenuItem(title: "All Regions...", action: nil, keyEquivalent: "")
        let allRegionsSubmenu = NSMenu()
        allRegionsSubmenu.delegate = self
        
        for region in MarketRegion.allRegions {
            let item = NSMenuItem(title: region.displayName, action: #selector(previewRegionSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = region.code
            allRegionsSubmenu.addItem(item)
        }
        
        allRegionsItem.submenu = allRegionsSubmenu
        submenu.addItem(allRegionsItem)
        
        return submenu
    }
    
    /// Update tick marks in region submenu based on current preview region
    private func updateRegionMenuTickMarks(menu: NSMenu) {
        let activeRegion = previewRegion ?? settings.marketRegion
        
        for item in menu.items {
            if let code = item.representedObject as? String {
                if code == "BACK_TO_MY_REGION" {
                    // Tick "Back to My Region" only if we're not previewing another region
                    item.state = (previewRegion == nil) ? .on : .off
                } else {
                    item.state = (code == activeRegion) ? .on : .off
                }
            }
            
            // Also update submenu items
            if let submenu = item.submenu {
                updateRegionMenuTickMarks(menu: submenu)
            }
        }
    }
    
    @MainActor
    @objc func backToMyRegion(_ sender: NSMenuItem) {
        previewRegion = nil
        showNewestImage()
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    @MainActor
    @objc func previewRegionSelected(_ sender: NSMenuItem) {
        guard let regionCode = sender.representedObject as? String else { return }
        
        // If it's the same as current region, just show local images
        if regionCode == settings.marketRegion && previewRegion == nil {
            return
        }
        
        previewRegion = regionCode
        
        // Load the preview and reopen menu when done
        Task { @MainActor in
            await loadPreviewFromRegion(regionCode)
            // Reopen the menu to show the preview
            reopenMenu()
        }
    }
    
    @MainActor
    private func reopenMenu() {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        // Small delay to ensure smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            button.performClick(nil)
        }
    }
    
    @MainActor
    private func loadPreviewFromRegion(_ regionCode: String) async {
        guard !isLoadingRegionPreview else { return }
        isLoadingRegionPreview = true
        
        // Show loading state with spinner-like icon
        let loadingImage = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Loading")
        loadingImage?.isTemplate = true
        imageSelectorView.imageView.image = loadingImage
        
        // Update title to show loading region
        let regionName = MarketRegion.region(for: regionCode)?.displayName ?? regionCode
        updateLoadingTextView(message: "Loading image from \(regionName)...")
        
        do {
            let entries = try await DownloadManager.downloadImageEntries(numberOfImages: 1, market: regionCode)
            
            guard let entry = entries.first else {
                isLoadingRegionPreview = false
                updateLoadingTextView(message: "No image available for this region")
                return
            }
            
            // Download the image temporarily (not saving to disk)
            let imageUrl = URL(string: "https://www.bing.com" + entry.url)!
            let imageData = try await DownloadManager.downloadBinary(from: imageUrl)
            
            isLoadingRegionPreview = false
            
            // Display the image
            if let image = NSImage(data: imageData) {
                self.imageSelectorView.imageView.image = image
            }
            
            // Update text view with region info
            self.updateTextViewForRegionPreview(entry: entry, regionCode: regionCode)
        } catch {
            isLoadingRegionPreview = false
            print("Failed to load region preview: \(error)")
        }
    }
    
    @MainActor
    private func updateTextViewForRegionPreview(entry: DownloadManager.ImageEntry, regionCode: String) {
        guard let menu = menu else { return }
        
        let regionName = MarketRegion.region(for: regionCode)?.displayName ?? regionCode
        
        let textItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        textItem.tag = MenuController.TEXT_VIEW_TAG
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: 0))
        
        // Show region name in description
        let description = String(entry.copyright.split(separator: "(").first ?? "")
        textView.descriptionLabel.stringValue = "[\(regionName)] \(description)"
        textView.copyrightLabel.stringValue = entry.copyright.split(separator: "(").last?.replacingOccurrences(of: ")", with: "") ?? ""
        textView.button.action = #selector(openRegionPreviewLink(_:))
        textView.button.target = self
        textView.button.tag = entry.copyrightlink.hashValue
        
        // Store the URL for the button
        if let button = textView.button {
            objc_setAssociatedObject(button, "copyrightLink", entry.copyrightlink, .OBJC_ASSOCIATION_RETAIN)
        }
        
        textItem.view = textView
        
        if let oldTextItem = menu.item(withTag: MenuController.TEXT_VIEW_TAG) {
            menu.removeItem(oldTextItem)
        }
        let imageView = menu.item(withTag: MenuController.IMAGE_VIEW_TAG)!
        let textViewIndex = menu.index(of: imageView) + 1
        menu.insertItem(textItem, at: textViewIndex)
        
        // Disable navigation buttons when previewing other regions
        imageSelectorView.leftButton.isEnabled = false
        imageSelectorView.rightButton.isEnabled = false
    }
    
    @objc func openRegionPreviewLink(_ sender: NSButton) {
        if let urlString = objc_getAssociatedObject(sender, "copyrightLink") as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @MainActor
    private func updateLoadingTextView(message: String) {
        guard let menu = menu else { return }
        
        let textItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        textItem.tag = MenuController.TEXT_VIEW_TAG
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: 0))
        textView.descriptionLabel.stringValue = message
        textView.copyrightLabel.stringValue = ""
        textView.button.isHidden = true
        textItem.view = textView
        
        if let oldTextItem = menu.item(withTag: MenuController.TEXT_VIEW_TAG) {
            menu.removeItem(oldTextItem)
        }
        let imageView = menu.item(withTag: MenuController.IMAGE_VIEW_TAG)!
        let textViewIndex = menu.index(of: imageView) + 1
        menu.insertItem(textItem, at: textViewIndex)
    }
}

// MARK: - Delegates

extension MenuController: UpdateManagerDelegate {
    func downloadedNewImage() {
        showNewestImage()
    }
}

extension MenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Only update image selector for the main menu, not submenus
        if menu == self.menu {
            updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
        }
        updateRegionMenuTickMarks(menu: menu)
    }
}

extension MenuController: SettingsVcDelegate {
    func showMenuBarIcon() {
        setup()
    }
    
    func hideMenuBarIcon() {
        guard let statusItem = statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.menu?.removeAllItems()
        self.menu = nil
        self.statusItem = nil
    }
}
