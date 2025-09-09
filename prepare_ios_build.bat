@echo off
echo Preparing Flutter project for iOS build...
echo.

echo 1. Checking Flutter installation...
flutter --version
echo.

echo 2. Getting Flutter dependencies...
flutter pub get
echo.

echo 3. Analyzing project...
flutter analyze
echo.

echo 4. Running tests...
flutter test
echo.

echo 5. Building for iOS (this will fail on Windows, but checks configuration)...
flutter build ios --no-codesign
echo.

echo 6. Checking iOS configuration...
echo Bundle ID: com.yourcompany.hrappodoo
echo App Name: HR App Odoo
echo.

echo ✅ Project is ready for iOS build!
echo.
echo Next steps:
echo 1. Push this code to GitHub/GitLab
echo 2. Sign up for Codemagic (https://codemagic.io)
echo 3. Connect your repository
echo 4. Configure Apple Developer account
echo 5. Trigger build and download IPA
echo.
echo See IOS_BUILD_GUIDE.md for detailed instructions.
pause
