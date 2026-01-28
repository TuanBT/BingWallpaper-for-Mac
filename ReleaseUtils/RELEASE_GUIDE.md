# 📦 Release Guide for BingWallpaper

## Method 1: Using Script (Automated)

### Requirements:
- ✅ Full Xcode installed (not just Command Line Tools)
- ✅ Git installed

### Steps:

1. **Grant execute permission to the script:**
```bash
cd BingWallpaper-for-Mac
chmod +x ./build_release.sh
```

2. **Run the script:**
```bash
./ReleaseUtils/build_release.sh
```

3. **Output:**
- ✅ `BingWallpaper_latest.zip` – ZIP archive of the app  
- ✅ `BingWallpaper_latest.pkg` – PKG installer (this file is uploaded to GitHub)

---

## Method 2: Manual Build from Xcode (Easier if Xcode CLI is not installed)

### Step 1: Build in Xcode

1. Open `BingWallpaper.xcodeproj` in Xcode
2. Select the **BingWallpaper** target in the toolbar
3. Menu: **Product → Build** (⌘B)
4. Locate the `.app` file:
   - Click **Products** in the Project Navigator (left panel)
   - Right-click **BingWallpaper.app** → **Show in Finder**

### Step 2: Create PKG Installer

```bash
# Assume BingWallpaper.app is located in:
# ~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/
cd ~/Library/Developer/Xcode/DerivedData/BingWallpaper-*/Build/Products/Release/

pkgbuild \
  --root BingWallpaper.app \
  --scripts BingWallpaper-for-Mac/ReleaseUtils \
  --install-location /Applications/BingWallpaper.app \
  ~/Desktop/BingWallpaper_latest.pkg
```

---

## Method 3: Build and Archive (Professional)

### Step 1: Archive in Xcode

1. Open `BingWallpaper.xcodeproj`
2. Select the **BingWallpaper** target
3. Make sure **Any Mac** is selected (not a simulator)
4. Menu: **Product → Archive**
5. Wait for the archive process to complete

### Step 2: Export App

1. Organizer will open automatically after archiving
2. Select the newly created archive
3. Click **Distribute App**
4. Choose **Copy App**
5. Select a destination folder (e.g. Desktop)

### Step 3: Create PKG

```bash
cd ~/Desktop

pkgbuild \
  --root BingWallpaper.app \
  --scripts BingWallpaper-for-Mac/ReleaseUtils \
  --install-location /Applications/BingWallpaper.app \
  BingWallpaper_latest.pkg
```

---

## 🚀 Upload to GitHub Release

### Step 1: Create a Tag

```bash
cd BingWallpaper-for-Mac

# Check current version in Info.plist
cat BingWallpaper/Helper/Info.plist | grep -A1 CFBundleShortVersionString

# Create tag (replace v1.0.0 with your version)
git tag v1.0.0
git push origin v1.0.0
```

### Step 2: Create a Release on GitHub

1. Go to: https://github.com/TuanBTBingWallpaper-for-Mac/releases/new
2. **Choose a tag:** Select the tag you just created (v1.0.0)
3. **Release title:** `BingWallpaper v1.0.0`
4. **Description:** Write release notes (new features, bug fixes, etc.)
5. **Attach files:** Upload `BingWallpaper_latest.pkg`
6. Click **Publish release**

---

## 🧪 Testing the Update Feature

### Step 1: Simulate an Older Version

1. Open `BingWallpaper/Helper/Info.plist`
2. Find `CFBundleShortVersionString`
3. Change it to a lower version (e.g. `0.9.0`)

### Step 2: Build and Test

1. Build the app in Xcode (⌘B)
2. Run the app (⌘R)
3. Click the BingWallpaper menu bar icon
4. Select **Check for app update**
5. **Expected result:** A dialog appears showing a newer version with an **Update** button

---

## ❓ Troubleshooting

### Error: "tool 'xcodebuild' requires Xcode"

**Cause:** Only Command Line Tools are installed, full Xcode is missing

**Fix:**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Error: "pkgbuild: error: Specified root path does not exist"

**Cause:** Incorrect path to `BingWallpaper.app`

**Fix:**
```bash
find ~/Library/Developer/Xcode -name "BingWallpaper.app" 2>/dev/null
```

### Script does not run

**Fix:**
```bash
chmod +x ReleaseUtils/build_release.sh
```

---

## 📝 Notes

- Only the `.pkg` file needs to be uploaded to GitHub
- No need to upload the `.zip` file
- The Git tag version must match the version in `Info.plist`
- The script automatically generates both `.pkg` and `.zip`
