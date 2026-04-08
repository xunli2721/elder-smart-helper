/**
 * @format
 */

import { AppRegistry } from 'react-native';
import App from './src/App';
import { name as appName } from './app.json';

// Import polyfills and global configurations
import './src/config/polyfills';
import './src/config/global';

// Register the app
AppRegistry.registerComponent(appName, () => App);