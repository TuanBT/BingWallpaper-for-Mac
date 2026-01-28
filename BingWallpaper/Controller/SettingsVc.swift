import Cocoa

protocol SettingsVcDelegate: AnyObject {
    @MainActor
    func showMenuBarIcon()
    @MainActor
    func hideMenuBarIcon()
}

class SettingsVc: NSViewController {
    @IBOutlet var launchAtLoginCheckBox: NSButton!
    @IBOutlet weak var hideMenuBarIconCheckBox: NSButton!
    @IBOutlet var imagePathButton: NSButton!
    @IBOutlet weak var keepImagesSlider: NSSlider!
    @IBOutlet weak var keepImagesTextField: NSTextField!
    @IBOutlet weak var updateIntervalTextField: NSTextField!
    @IBOutlet weak var updateIntervalLabel: NSTextField!
    @IBOutlet weak var marketRegionPopup: NSPopUpButton!
    @IBOutlet weak var scheduledUpdateCheckBox: NSButton!
    @IBOutlet weak var scheduledHourTextField: NSTextField!
    @IBOutlet weak var scheduledMinuteTextField: NSTextField!
    @IBOutlet weak var scheduledTimeLabel: NSTextField!
    
    private let settings = Settings()
    weak var delegate: SettingsVcDelegate?
    weak var updateManager: UpdateManager?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        launchAtLoginCheckBox.state = settings.launchAtLogin ? .on : .off
        hideMenuBarIconCheckBox.state = settings.hideMenuBarIcon ? .on : .off
        imagePathButton.title = settings.imageDownloadPath.path
        imagePathButton.toolTip = imagePathButton.title
        
        // Configure slider for 5 options: 1, 2, 5, 10, ∞
        keepImagesSlider.minValue = 0
        keepImagesSlider.maxValue = 4
        keepImagesSlider.numberOfTickMarks = 5
        keepImagesSlider.allowsTickMarkValuesOnly = true
        keepImagesSlider.integerValue = settings.keepImageDuration
        setKeepImagesText()
        
        updateIntervalTextField.doubleValue = settings.updateIntervalHours
        setUpdateIntervalText()
        setupMarketRegionPopup()
        setupScheduledUpdate()
    }
    
    // MARK: - Actions
    
    @IBAction func launchAtLoginAction(_ sender: NSButton) {
        let newState = sender.state == .on
        settings.launchAtLogin = newState
    }
    
    @IBAction func hideMenuBarIconCheckBoxAction(_ sender: NSButton) {
        let newState = sender.state == .on
        settings.hideMenuBarIcon = newState
        if newState == true {
            delegate?.hideMenuBarIcon()
        } else {
            delegate?.showMenuBarIcon()
        }
    }
    
    @IBAction func imagePathButtonAction(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = true
        
        if dialog.runModal() == NSApplication.ModalResponse.OK {
            guard let result = dialog.url else { return }
            settings.imageDownloadPath = result
            imagePathButton.title = result.path
            imagePathButton.toolTip = result.path
        }
    }
    
    @IBAction func keepImagesSliderAction(_ sender: NSSlider) {
        settings.keepImageDuration = sender.integerValue
        setKeepImagesText()
    }
    
    @IBAction func updateIntervalTextFieldAction(_ sender: NSTextField) {
        let hours = max(0.1, sender.doubleValue) // Minimum 0.1 hour (6 minutes)
        settings.updateIntervalHours = hours
        updateIntervalTextField.doubleValue = hours
        setUpdateIntervalText()
    }
    
    @IBAction func marketRegionPopupAction(_ sender: NSPopUpButton) {
        if let selectedItem = sender.selectedItem, let marketCode = selectedItem.representedObject as? String {
            settings.marketRegion = marketCode
        }
    }
    
    @IBAction func scheduledUpdateCheckBoxAction(_ sender: NSButton) {
        let useScheduled = sender.state == .on
        settings.useScheduledUpdate = useScheduled
        updateScheduledTimeFieldsEnabled()
        updateManager?.reschedule()
    }
    
    @IBAction func scheduledHourTextFieldAction(_ sender: NSTextField) {
        let hour = max(0, min(23, sender.integerValue))
        settings.scheduledUpdateHour = hour
        scheduledHourTextField.integerValue = hour
        setScheduledTimeLabel()
        updateManager?.reschedule()
    }
    
    @IBAction func scheduledMinuteTextFieldAction(_ sender: NSTextField) {
        let minute = max(0, min(59, sender.integerValue))
        settings.scheduledUpdateMinute = minute
        scheduledMinuteTextField.integerValue = minute
        setScheduledTimeLabel()
        updateManager?.reschedule()
    }
    
    @IBAction func resetDatabaseButtonAction(_ sender: NSButton) {
        print("Resetting Database...")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"  // Use yyyy (calendar year), not YYYY (week year)
        let oldestDateStringToKeep = dateFormatter.string(from: Date())
        
        do {
            try Database.instance.deleteImageDescriptors(olderThan: oldestDateStringToKeep)
        } catch let error {
            print("Failed resetting Database: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Failed to reset Database"
            alert.informativeText = error.localizedDescription
            let updateButton = alert.addButton(withTitle: "Ok")
            alert.alertStyle = .informational
            alert.window.defaultButtonCell = updateButton.cell as? NSButtonCell
            alert.runModal()
        }
        
        updateManager?.update()
    }
    
    // MARK: - Private
    
    private func setKeepImagesText() {
        guard let keepImageDuration = KeepImageDuration(rawValue: settings.keepImageDuration) else { return }
        
        switch keepImageDuration {
        case .one, .two, .five, .ten:
            let dayText = keepImageDuration.text == "1" ? "day" : "days"
            keepImagesTextField.stringValue = "Keep images from last \(keepImageDuration.text) \(dayText):"
        case .infinite:
            keepImagesTextField.stringValue = "Keep all images forever:"
        }
    }
    
    private func setUpdateIntervalText() {
        let hours = settings.updateIntervalHours
        if hours < 1.0 {
            let minutes = Int(hours * 60)
            updateIntervalLabel.stringValue = "Update wallpaper every \(minutes) minutes"
        } else if hours == 1.0 {
            updateIntervalLabel.stringValue = "Update wallpaper every hour"
        } else {
            updateIntervalLabel.stringValue = "Update wallpaper every \(String(format: "%.1f", hours)) hours"
        }
    }
    
    private func setupMarketRegionPopup() {
        guard let marketRegionPopup = marketRegionPopup else {
            print("Warning: marketRegionPopup outlet is not connected")
            return
        }
        
        let markets: [(name: String, code: String)] = [
            ("Global (English - Australia)", "en-AU"),
            ("Global (English - Canada)", "en-CA"),
            ("Global (English - India)", "en-IN"),
            ("Global (English - UK)", "en-GB"),
            ("Global (English - US)", "en-US"),
            ("Argentina", "es-AR"),
            ("Austria", "de-AT"),
            ("Belgium (Dutch)", "nl-BE"),
            ("Belgium (French)", "fr-BE"),
            ("Brazil", "pt-BR"),
            ("Bulgaria", "bg-BG"),
            ("Chile", "es-CL"),
            ("China (Simplified)", "zh-CN"),
            ("China (Traditional - Hong Kong)", "zh-HK"),
            ("China (Traditional - Taiwan)", "zh-TW"),
            ("Colombia", "es-CO"),
            ("Croatia", "hr-HR"),
            ("Czech Republic", "cs-CZ"),
            ("Denmark", "da-DK"),
            ("Egypt", "ar-EG"),
            ("Finland", "fi-FI"),
            ("France", "fr-FR"),
            ("Germany", "de-DE"),
            ("Greece", "el-GR"),
            ("Hungary", "hu-HU"),
            ("Indonesia", "id-ID"),
            ("Israel", "he-IL"),
            ("Italy", "it-IT"),
            ("Japan", "ja-JP"),
            ("Korea", "ko-KR"),
            ("Malaysia", "ms-MY"),
            ("Mexico", "es-MX"),
            ("Netherlands", "nl-NL"),
            ("Norway", "nb-NO"),
            ("Peru", "es-PE"),
            ("Philippines", "en-PH"),
            ("Poland", "pl-PL"),
            ("Portugal", "pt-PT"),
            ("Romania", "ro-RO"),
            ("Russia", "ru-RU"),
            ("Saudi Arabia", "ar-SA"),
            ("Serbia", "sr-RS"),
            ("Singapore", "en-SG"),
            ("Slovakia", "sk-SK"),
            ("Slovenia", "sl-SI"),
            ("South Africa", "en-ZA"),
            ("Spain", "es-ES"),
            ("Sweden", "sv-SE"),
            ("Switzerland (French)", "fr-CH"),
            ("Switzerland (German)", "de-CH"),
            ("Thailand", "th-TH"),
            ("Turkey", "tr-TR"),
            ("UAE", "ar-AE"),
            ("Ukraine", "uk-UA"),
            ("Vietnam", "vi-VN")
        ]
        
        marketRegionPopup.removeAllItems()
        
        for market in markets {
            marketRegionPopup.addItem(withTitle: market.name)
            marketRegionPopup.lastItem?.representedObject = market.code
            
            if market.code == settings.marketRegion {
                marketRegionPopup.select(marketRegionPopup.lastItem)
            }
        }
    }
    
    private func setupScheduledUpdate() {
        guard let scheduledUpdateCheckBox = scheduledUpdateCheckBox,
              let scheduledHourTextField = scheduledHourTextField,
              let scheduledMinuteTextField = scheduledMinuteTextField,
              let scheduledTimeLabel = scheduledTimeLabel else {
            return
        }
        
        scheduledUpdateCheckBox.state = settings.useScheduledUpdate ? .on : .off
        scheduledHourTextField.integerValue = settings.scheduledUpdateHour
        scheduledMinuteTextField.integerValue = settings.scheduledUpdateMinute
        updateScheduledTimeFieldsEnabled()
        setScheduledTimeLabel()
    }
    
    private func updateScheduledTimeFieldsEnabled() {
        guard let scheduledHourTextField = scheduledHourTextField,
              let scheduledMinuteTextField = scheduledMinuteTextField,
              let updateIntervalTextField = updateIntervalTextField else {
            return
        }
        
        let useScheduled = settings.useScheduledUpdate
        scheduledHourTextField.isEnabled = useScheduled
        scheduledMinuteTextField.isEnabled = useScheduled
        updateIntervalTextField.isEnabled = !useScheduled
    }
    
    private func setScheduledTimeLabel() {
        guard let scheduledTimeLabel = scheduledTimeLabel else { return }
        
        let hour = settings.scheduledUpdateHour
        let minute = settings.scheduledUpdateMinute
        scheduledTimeLabel.stringValue = String(format: "Update daily at %02d:%02d", hour, minute)
    }
}

enum KeepImageDuration: Int {
    case one
    case two
    case five
    case ten
    case infinite
    
    var text: String {
        switch self {
        case .one:
            return "1"
        case .two:
            return "2"
        case .five:
            return "5"
        case .ten:
            return "10"
        case .infinite:
            return "∞"
        }
    }
}
