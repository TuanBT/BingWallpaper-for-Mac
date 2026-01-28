# Bing Wallpaper for Mac

 <p align="center">
 <img width="400" alt="screenshot" src="https://user-images.githubusercontent.com/4823365/181782535-6235edf9-5e70-4861-96df-b4e2719482cf.png">
 </p>

 BingWallpaper is a menubar app for macOS that automatically downloads the newest [Bing wallpaper of the day](https://www.microsoft.com/bing/bing-wallpaper) and sets it as wallpaper for all your monitors and spaces.

 ## Features

 ### 🖼️ Automatic Wallpaper Updates
 - Automatically downloads and applies the daily Bing wallpaper
 - Works across all monitors and spaces (uses AppleScript for reliable multi-space support)
 - Runs silently in the background from your menubar

 ### 🌍 Market Region Selection
 - Choose from 50+ countries/regions to get localized Bing wallpapers
 - Supported regions include: US, UK, Germany, France, Japan, China, Vietnam, and many more
 - Different regions may feature different daily images

 ### 🔍 Browse Other Regions (NEW!)
 - Preview wallpapers from any region without changing your settings
 - Quickly explore what other countries have for their daily Bing image
 - Popular regions are highlighted for easy access
 - Perfect for finding unique wallpapers from around the world

 ### ⏰ Flexible Update Scheduling
 Two update modes available:

 **Interval Mode (Default)**
 - Set how often to check for new wallpapers (in hours)
 - Example: Update every 3 hours

 **Scheduled Mode**
 - Set a specific time each day for updates
 - Perfect for updating at midnight (00:00) when new Bing images are released
 - If your Mac is asleep/off at the scheduled time, the app will update immediately when you wake it up

 ### 💾 Image Management
 - Choose custom download location for wallpaper images
 - Configure how many days of images to keep on disk (1, 2, 5, 10 days, or unlimited)
 - Automatic cleanup of old images

 ### 🎛️ System Integration
 - Launch at login option
 - Hide menubar icon option (access settings via right-click or keyboard shortcut)
 - Reset database functionality
 - Check for app updates directly from GitHub releases

 ## Settings

 | Setting | Description |
 |---------|-------------|
 | **Launch at login** | Start BingWallpaper automatically when you log in |
 | **Hide icon at menubar** | Hide the app icon from the menubar |
 | **Market Region** | Select your preferred region for Bing images |
 | **Update interval** | How often to check for new wallpapers (hours) |
 | **Update at specific time** | Enable scheduled daily updates at a specific time |
 | **Image location** | Where to save downloaded wallpaper images |
 | **Keep images on disk** | How many days of images to retain (1/2/5/10/∞) |
 | **Reset Database** | Clear the image database and re-download |

 ## Usage

 ### Installation
 
 Download the latest version from the [Releases page](https://github.com/TuanBT/BingWallpaper-for-Mac/releases/latest).
 
 **Important:** Since the app is not code-signed, macOS will show a security warning. See the [Installation Guide](INSTALLATION.md) for detailed instructions on how to install the app.

 ### Basic Usage
 1. Install and launch the app
 2. The app will automatically download and set the current Bing wallpaper
 3. Access the menu by clicking the menubar icon

 ### Browsing Other Regions
 To preview wallpapers from other countries:
 1. Click the menubar icon
 2. Hover over "Browse Other Regions"
 3. Select a region from the list (popular regions shown first)
 4. The preview will load and display in the menu
 5. Use "Back to My Region" to return to your configured region

 ### Setting Up Midnight Updates
 To update wallpapers at midnight each day:
 1. Open Settings
 2. Check "Update at specific time"
 3. Set Hour to `0` and Minute to `0`
 4. The app will now update daily at 00:00

 ### Changing Region
 To get wallpapers from a specific country:
 1. Open Settings
 2. Click the "Market Region" dropdown
 3. Select your preferred region (e.g., "Vietnam" for vi-VN)
 4. New wallpapers will use this region

 ## Requirements

 - macOS 11.0 (Big Sur) or later
 - Internet connection for downloading wallpapers
 - System Events permission (for setting wallpaper across all Spaces)

 ## License

 This project is open source. Clone from https://github.com/2h4u/BingWallpaper-for-Mac