# iOS Build Guide for HR App Odoo

## 🚀 Quick Start with Codemagic (Recommended)

### Step 1: Prepare Your Project
1. Make sure your Flutter project is in a Git repository (GitHub, GitLab, or Bitbucket)
2. Update your `ios/Runner/Info.plist` with proper bundle identifier
3. Ensure all dependencies are properly configured

### Step 2: Set Up Codemagic
1. Go to [codemagic.io](https://codemagic.io)
2. Sign up with your Git provider (GitHub/GitLab/Bitbucket)
3. Connect your repository
4. The `codemagic.yaml` file I created will be automatically detected

### Step 3: Configure iOS Settings
1. In Codemagic dashboard, go to your app settings
2. Set up Apple Developer account integration
3. Add your Apple Developer credentials
4. Configure code signing certificates

### Step 4: Build
1. Trigger a build manually or push to your main branch
2. Codemagic will build your iOS app in the cloud
3. Download the IPA file when build completes

## 📱 Alternative: Manual iOS Setup

### Update iOS Configuration

1. **Update Bundle Identifier** in `ios/Runner/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>com.yourcompany.hrappodoo</string>
```

2. **Update App Name** in `ios/Runner/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>HR App Odoo</string>
```

3. **Add Required Permissions** in `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for face recognition attendance</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for attendance verification</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access for attendance verification</string>
```

## 🔧 Local iOS Development (If you have access to Mac)

### Prerequisites
- macOS with Xcode installed
- Apple Developer account
- Flutter SDK

### Commands
```bash
# Navigate to your project
cd hr_app_odoo

# Get dependencies
flutter pub get

# Build for iOS
flutter build ios --release

# Build IPA
flutter build ipa --release
```

## 📦 Using Mac in Cloud Services

### Option 1: MacStadium
- Rent a Mac remotely
- Access via VNC or screen sharing
- Build your app in the cloud

### Option 2: AWS EC2 Mac Instances
- Launch macOS instances on AWS
- Use for building iOS apps
- Pay per hour usage

## 🎯 Recommended Approach

**For testing purposes, I recommend using Codemagic because:**
1. ✅ No need for Mac hardware
2. ✅ Free tier available
3. ✅ Automatic builds on code changes
4. ✅ Easy to set up
5. ✅ Professional build environment

## 📋 Next Steps

1. Push your code to GitHub/GitLab
2. Sign up for Codemagic
3. Connect your repository
4. Configure Apple Developer account
5. Trigger your first build
6. Download the IPA file

## 🔍 Troubleshooting

### Common Issues:
- **Code signing errors**: Make sure Apple Developer account is properly configured
- **Build failures**: Check Flutter version compatibility
- **Permission errors**: Verify Info.plist permissions are correct

### Support:
- Codemagic documentation: https://docs.codemagic.io
- Flutter iOS deployment: https://docs.flutter.dev/deployment/ios
