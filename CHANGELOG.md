## [0.1.0] - September 20, 2025

### 🎉 Major Release - Package Rename & Modernization

#### 💥 Breaking Changes
- **Package renamed** from `chatwoot_sdk` to `chatwoot_flutter_sdk`
- **Removed deprecated components**: `ChatwootChat` and `ChatwootChatDialog`
- **Updated import statements**: Use `package:chatwoot_flutter_sdk/chatwoot_sdk.dart`

#### ✨ New Features
- **Custom Flutter Chat Example**: Added comprehensive `CustomChatPage` implementation using `flutter_chat_ui`
- **Enhanced Documentation**: Complete README overhaul with modern examples and clear setup guides
- **Publisher Integration**: Package ready for publication under African Permanent Innovations

#### 🐛 Bug Fixes
- **Null Safety**: Fixed null safety issues in example app's CustomChatPage
- **Dependencies**: Added missing `webview_flutter_android` dependency
- **Analysis**: Resolved all static analysis issues (753 → 0 issues)

#### 🔧 Technical Improvements
- **Test Coverage**: All 63 tests passing with comprehensive coverage
- **Build System**: Updated to latest Flutter SDK and dependencies
- **File Structure**: Added `.pubignore` to exclude development files from publication
- **Code Quality**: Removed unused imports and unreachable code

#### 📚 Documentation
- **Modern README**: Added features list, installation guide, and comprehensive examples
- **API Documentation**: Enhanced parameter tables and callback documentation
- **Example App**: Updated with file picker integration and real-time messaging demo

#### 🚀 Development Notes
- Full native chat UI components are in development for future releases
- Current native implementation provides basic chat interface example
- WebView widget remains the recommended solution for production use

---

## Previous Versions (chatwoot_sdk)

## [0.0.9] - Jul 22,2021

- Fixed message sending issues
- Adds development docs

## [0.0.8] - Jul 22,2021

- Update dependencies

## [0.0.7] - Jul 22,2021

- Fixed ChatwootChatDialog avatar color
- Fixed ChatwootChatDialog chat bubble overflow

## [0.0.6] - Jul 20,2021

- Fixed received message widget overflow on mobile screens

## [0.0.5] - Jul 20,2021

- Added ChatwootChatModal
- Updated README.md

## [0.0.4] - Jul 15,2021

- Updated build_runner dependency to null safety version

## [0.0.3] - Jul 15,2021

- Fixed multiple Hive adapter registration issue
- Fixed theme background issue
- Resolved pub analysis issues

