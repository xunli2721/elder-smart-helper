# ElderSmartHelper - Mobile Application

## Overview
This is the mobile application for ElderSmartHelper, designed specifically for elderly users with age-friendly interfaces, simple navigation, and essential smartphone assistance features.

## Features
- **Age-Friendly UI**: Large fonts, high contrast, simplified layouts
- **Voice Interaction**: Speech recognition and synthesis for hands-free operation
- **Step-by-Step Tutorials**: Visual guides for common smartphone operations
- **Remote Assistance**: Screen sharing and real-time guidance from family members
- **Security Features**: Fraud detection, payment protection, risk alerts
- **Personalization**: Adjustable font size, speech speed, gesture sensitivity

## Technology Stack
- **Framework**: React Native (cross-platform) / Flutter
- **State Management**: Redux / MobX / Provider
- **Navigation**: React Navigation
- **UI Components**: Custom age-friendly components
- **Real-time Communication**: WebSocket / Socket.io
- **Local Storage**: AsyncStorage / SQLite

## Project Structure
```
mobile-app/
├── src/
│   ├── assets/         # Images, fonts, icons
│   ├── components/     # Reusable UI components
│   ├── screens/        # App screens/pages
│   ├── navigation/     # Navigation configuration
│   ├── services/       # API calls, WebSocket, etc.
│   ├── store/         # State management
│   ├── utils/         # Helper functions
│   └── constants/     # App constants
├── android/           # Android-specific files
├── ios/               # iOS-specific files
├── tests/             # Test files
└── config/            # Configuration files
```

## Getting Started

### Prerequisites
- Node.js v16+
- React Native CLI or Expo CLI
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

### Installation
1. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your API endpoints
   ```

3. Run on Android:
   ```bash
   npm run android
   # or
   npx react-native run-android
   ```

4. Run on iOS:
   ```bash
   npm run ios
   # or
   npx react-native run-ios
   ```

### Development Guidelines

#### UI/UX Principles for Elderly Users
1. **Simplicity**: One primary action per screen
2. **Visibility**: Large touch targets (minimum 44x44px)
3. **Consistency**: Predictable navigation patterns
4. **Feedback**: Clear visual and audio feedback
5. **Error Prevention**: Minimize opportunities for errors

#### Component Design
- Use high contrast color schemes (minimum 4.5:1 ratio)
- Implement scalable fonts (support dynamic type)
- Provide audio cues for important actions
- Include haptic feedback where appropriate

### Testing
- **Unit Tests**: Jest for JavaScript logic
- **Component Tests**: React Native Testing Library
- **Accessibility Tests**: VoiceOver/TalkBack compatibility
- **User Testing**: Involve elderly users in usability testing

### Building for Production
See [BUILD.md](BUILD.md) for build and deployment instructions.

## License
MIT