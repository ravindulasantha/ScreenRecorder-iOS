# Placeholder App Store Assets

This directory contains placeholder assets for App Store submission. These are NOT production-ready assets and should be replaced with actual high-quality graphics before submission.

## App Icon (`app_icon_1024x1024.png`)
- This is a placeholder for the main app icon (1024x1024 pixels) required by App Store Connect.
- You will also need to generate various other sizes for the app binary itself, typically managed by Flutter/Xcode using an icon asset generator or by providing them in an asset catalog (`ios/Runner/Assets.xcassets/AppIcon.appiconset`).

## Screenshots
The `.png` files in this directory are placeholders. Replace them with actual screenshots of your application.

**Required Screenshot Sizes (Common Set for iOS):**

Apple requires screenshots for different device sizes. The primary ones you'll typically need to upload to App Store Connect are:

1.  **iPhone 6.7-inch Display:**
    *   Size: 1290 x 2796 pixels (portrait) or 2796 x 1290 pixels (landscape)
    *   Devices: iPhone 15 Pro Max, iPhone 15 Plus, iPhone 14 Pro Max, iPhone 14 Plus, iPhone 13 Pro Max, iPhone 12 Pro Max.
    *   Placeholder: `screenshot_1_iphone_6.7.png`, `screenshot_2_iphone_6.7.png`

2.  **iPhone 5.5-inch Display (Older, but often still required or good to have):**
    *   Size: 1242 x 2208 pixels (portrait) or 2208 x 1242 pixels (landscape)
    *   Devices: iPhone 8 Plus, iPhone 7 Plus, iPhone 6s Plus.
    *   *No specific placeholder provided here, but you can use the 6.7-inch and App Store Connect might allow you to use them for this size if they scale appropriately, or you may need to provide specific ones.*

3.  **iPad Pro 12.9-inch Display (3rd generation and later):**
    *   Size: 2048 x 2732 pixels (portrait) or 2732 x 2048 pixels (landscape)
    *   Devices: iPad Pro (12.9-inch, 3rd, 4th, 5th, 6th generation)
    *   Placeholder: `screenshot_1_ipad_pro_12.9.png`

**Notes on Screenshots:**
- You can provide 1 to 10 screenshots per device family.
- The first screenshot is the most important as it's the first one users see.
- Screenshots should accurately represent your app's functionality and UI.
- Avoid including device bezels in the screenshots unless it's part of a marketing image.
- App Store Connect may allow you to use screenshots from one device size for other similar-sized devices if they meet the criteria. Always check the latest requirements on App Store Connect.
- Consider localizing screenshots if your app supports multiple languages.

**Tools for Screenshots:**
- Simulator: Use `Cmd+S` in the iOS Simulator to save a screenshot.
- Physical Device: Take screenshots directly on your device.
- Frame generation tools (e.g., Fastlane Frameit, ShotBot) can help place your screenshots within device frames for marketing purposes (but upload plain screenshots to App Store Connect).
