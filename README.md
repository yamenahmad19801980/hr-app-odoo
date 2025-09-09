# HR App Odoo

A modern Flutter-based HR management application with a clean, professional design.

## Features

### 🔐 Login Screen
- Modern authentication interface
- Email and password validation
- Demo credentials for testing
- Smooth navigation to home screen

### 🏠 Home Screen
- **Time Tracking Module**: Real-time attendance tracking with check-in/check-out functionality
- **Status Display**: Shows current time, battery, and network status
- **User Greeting**: Personalized welcome message with profile picture
- **Feature Grid**: Quick access to essential HR functions:
  - Expense Management
  - Time Off Requests
  - Payslip Access
  - Attendance Records
  - Contract Management
  - Working Schedule

## Design Features

- **Clean UI**: White backgrounds with purple accents for a professional look
- **Responsive Design**: Optimized for mobile devices
- **Modern Icons**: Material Design icons throughout the interface
- **Color Scheme**: Purple gradient theme (#6B46C1 to #9F7AEA)
- **Card-based Layout**: Organized information in easy-to-read cards

## Getting Started

### Prerequisites
- Flutter SDK (^3.8.1)
- Dart SDK
- Android Studio / VS Code
- Android Emulator or iOS Simulator

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd hr_app_odoo
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Demo Credentials
For testing purposes, use these credentials:
- **Email**: admin@example.com
- **Password**: 123456

## Project Structure

```
lib/
├── main.dart              # App entry point and routing
└── screens/
    ├── login_screen.dart  # Authentication screen
    └── home_screen.dart   # Main dashboard
```

## Dependencies

- `flutter`: Core Flutter framework
- `cupertino_icons`: iOS-style icons
- `intl`: Internationalization support
- `shared_preferences`: Local data persistence

## Screenshots

The app includes:
- **Login Screen**: Professional authentication interface
- **Home Screen**: Complete HR dashboard with time tracking
- **Status Bar**: Simulated mobile status indicators
- **Time Tracking**: Real-time attendance monitoring
- **Feature Grid**: Quick access to HR functions

## Development

This app is built using Flutter's latest features:
- Material Design 3
- Stateful widgets for dynamic content
- Custom color schemes
- Responsive layouts
- Timer functionality for real-time updates

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Support

For support and questions, please open an issue in the repository.


////////////////////////////////////////////////////////////////////////

I can see from the GitHub Actions page that **GitHub Actions is currently disabled for your account**. This is why you can't see the workflow runs yet.

## 🔧 **How to Enable GitHub Actions:**

### **Option 1: Contact GitHub Support (Recommended)**
1. **Go to**: https://support.github.com
2. **Click "Contact GitHub Support"**
3. **Select "Account and Profile"** → **"Account settings"**
4. **Request**: "Please enable GitHub Actions for my account"
5. **Wait for response** (usually within 24 hours)

### **Option 2: Check Account Settings**
1. **Go to**: https://github.com/settings
2. **Look for "Actions"** in the left sidebar
3. **Check if there are any restrictions** or settings to enable

### **Option 3: Check Repository Settings**
1. **Go to**: https://github.com/yamenahmad19801980/hr-app-odoo/settings
2. **Click "Actions"** in the left sidebar
3. **Look for "Actions permissions"** section
4. **Make sure it's set to "Allow all actions"**

## �� **Why This Happens:**
- **New accounts** sometimes have Actions disabled by default
- **Account verification** might be required
- **Usage limits** might be reached
- **Account restrictions** from GitHub

## �� **Alternative: Use Codemagic (No GitHub Actions needed)**

Since GitHub Actions is disabled, let's use **Codemagic** instead - it's actually better for iOS builds:

### **Codemagic Setup (Free & Easy):**
1. **Go to**: https://codemagic.io
2. **Sign up** with your GitHub account
3. **Connect repository**: `yamenahmad19801980/hr-app-odoo`
4. **The `codemagic.yaml` file will be automatically detected**
5. **Click "Start new build"**
6. **Download IPA file** when complete

## 📱 **What You'll Get with Codemagic:**
- ✅ **No GitHub Actions needed**
- ✅ **Professional iOS build environment**
- ✅ **Free tier available** (500 build minutes/month)
- ✅ **Automatic builds** on code changes
- ✅ **Easy setup** - just connect your repo

## �� **Recommended Next Steps:**

1. **Try enabling GitHub Actions** (contact support)
2. **OR use Codemagic** (easier and more reliable for iOS)
3. **Both will give you the same result** - an IPA file for testing

Would you like me to help you set up Codemagic instead? It's actually the better option for iOS builds! 🚀