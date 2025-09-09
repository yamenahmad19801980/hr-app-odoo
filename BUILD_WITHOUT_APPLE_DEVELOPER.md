# 🚀 Build iOS App Without Apple Developer Account (For Testing)

## ⚠️ **Important Notes:**
- **This is for TESTING ONLY** - you cannot install on real iOS devices
- **No App Store distribution** - only for development/testing
- **Simulator testing** - works on iOS Simulator
- **Free Apple ID** - you only need a free Apple ID (not $99 developer account)

## 🔧 **Enable GitHub Actions:**

### Step 1: Enable Actions in Your Repository
1. Go to: https://github.com/yamenahmad19801980/hr-app-odoo
2. Click on **"Actions"** tab
3. Click **"I understand my workflows, go ahead and enable them"**
4. You should see the workflow: **"iOS Build (Test Mode - No Code Signing)"**

### Step 2: Trigger the Build
1. Go to **"Actions"** tab
2. Click on **"iOS Build (Test Mode - No Code Signing)"**
3. Click **"Run workflow"** button
4. Select **"main"** branch
5. Click **"Run workflow"**

## 📱 **What You'll Get:**

### ✅ **Build Artifacts:**
- **IPA file** (unsigned - for testing only)
- **iOS App Bundle** (.app file)
- **Build logs** for debugging

### ❌ **Limitations:**
- **Cannot install on real iPhone/iPad** (requires code signing)
- **Cannot distribute via App Store** (requires Apple Developer account)
- **Only works in iOS Simulator** (if you have Xcode)

## 🧪 **Testing Options:**

### Option 1: iOS Simulator (Free)
1. **Install Xcode** on Mac (free from App Store)
2. **Open iOS Simulator**
3. **Install your .app file** in simulator
4. **Test your app** functionality

### Option 2: TestFlight (Requires Apple Developer - $99/year)
1. **Get Apple Developer account**
2. **Upload IPA to App Store Connect**
3. **Add testers** via TestFlight
4. **Install on real devices** for testing

### Option 3: Local Development (Free)
1. **Install Flutter** on Mac
2. **Run**: `flutter run -d ios` (in simulator)
3. **Test directly** without building IPA

## 🔄 **How to Trigger Build:**

### Method 1: Manual Trigger
1. Go to Actions tab
2. Click "Run workflow"
3. Select main branch
4. Click "Run workflow"

### Method 2: Push Code Changes
1. Make any change to your code
2. Commit and push to main branch
3. GitHub Actions will automatically start

## 📋 **Build Process:**
1. **Checkout code** from your repository
2. **Setup Flutter** environment
3. **Install dependencies** (`flutter pub get`)
4. **Run tests** (`flutter test`)
5. **Analyze code** (`flutter analyze`)
6. **Build iOS app** (no code signing)
7. **Create IPA file** (unsigned)
8. **Upload artifacts** for download

## 🎯 **Next Steps After Build:**
1. **Download artifacts** from Actions tab
2. **Extract IPA file** from zip
3. **Test in iOS Simulator** (if you have Mac)
4. **Share with team** for feedback

## 💡 **Pro Tips:**
- **Build takes 5-10 minutes** on GitHub Actions
- **Artifacts expire in 7 days** (free tier)
- **Check build logs** if build fails
- **Use simulator** for UI testing

---
**Repository**: https://github.com/yamenahmad19801980/hr-app-odoo
**Status**: Ready for test build! 🎉
