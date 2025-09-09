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
