import React, { useEffect, useState } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Provider as StoreProvider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { NavigationContainer } from '@react-navigation/native';
import { StatusBar } from 'react-native';

// Import store and persistence
import { store, persistor } from './store';

// Import navigation
import AppNavigator from './navigation/AppNavigator';

// Import services
import { initializeAppServices } from './services/appService';
import { initializeVoiceAssistant } from './services/voiceService';
import { initializeSecurityMonitor } from './services/securityService';

// Import components
import SplashScreen from './components/SplashScreen';
import ErrorBoundary from './components/ErrorBoundary';
import NetworkStatus from './components/NetworkStatus';

// Import themes
import { ThemeProvider, useTheme } from './contexts/ThemeContext';
import { AccessibilityProvider } from './contexts/AccessibilityContext';
import { VoiceAssistantProvider } from './contexts/VoiceAssistantContext';

// Import utilities
import { loadFonts } from './utils/fontLoader';
import { checkPermissions } from './utils/permissions';

/**
 * Main App Component
 */
function AppContent() {
  const theme = useTheme();
  const [isReady, setIsReady] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      // Load fonts
      await loadFonts();

      // Check and request permissions
      await checkPermissions();

      // Initialize services
      await initializeAppServices();
      await initializeVoiceAssistant();
      await initializeSecurityMonitor();

      // Simulate splash screen delay
      setTimeout(() => {
        setIsReady(true);
      }, 2000);
    } catch (err) {
      console.error('Failed to initialize app:', err);
      setError(err.message || '应用初始化失败');
    }
  };

  if (error) {
    return (
      <ErrorBoundary error={error} onRetry={initializeApp} />
    );
  }

  if (!isReady) {
    return <SplashScreen />;
  }

  return (
    <>
      <StatusBar
        barStyle={theme.statusBarStyle}
        backgroundColor={theme.colors.primary}
      />
      <NavigationContainer
        theme={{
          colors: {
            primary: theme.colors.primary,
            background: theme.colors.background,
            card: theme.colors.surface,
            text: theme.colors.text,
            border: theme.colors.border,
            notification: theme.colors.notification,
          },
          fonts: theme.fonts,
        }}
      >
        <VoiceAssistantProvider>
          <AccessibilityProvider>
            <AppNavigator />
            <NetworkStatus />
          </AccessibilityProvider>
        </VoiceAssistantProvider>
      </NavigationContainer>
    </>
  );
}

/**
 * Root App Component with Providers
 */
export default function App() {
  return (
    <ErrorBoundary>
      <StoreProvider store={store}>
        <PersistGate loading={<SplashScreen />} persistor={persistor}>
          <SafeAreaProvider>
            <ThemeProvider>
              <AppContent />
            </ThemeProvider>
          </SafeAreaProvider>
        </PersistGate>
      </StoreProvider>
    </ErrorBoundary>
  );
}