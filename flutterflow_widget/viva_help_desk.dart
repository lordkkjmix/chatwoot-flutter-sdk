// FlutterFlow Custom Widget - VivaHelpDesk (Chatwoot Chat)
//
// DEPENDENCIES (add to pubspec.yaml):
//   webview_flutter: ^4.13.0
//   webview_flutter_android: ^4.7.0
//   webview_flutter_wkwebview: ^3.22.0
//   flutter_secure_storage: ^9.2.2
//
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/supabase/supabase.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================================
// CHATWOOT USER MODEL
// ============================================================================

/// User information for Chatwoot chat widget
class _ChatwootUser {
  final String? identifier;
  final String? identifierHash;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final dynamic customAttributes;

  _ChatwootUser({
    this.identifier,
    this.identifierHash,
    this.name,
    this.email,
    this.avatarUrl,
    this.customAttributes,
  });

  Map<String, dynamic> toJson() => {
        if (identifier != null) 'identifier': identifier,
        if (identifierHash != null) 'identifier_hash': identifierHash,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (customAttributes != null) 'custom_attributes': customAttributes,
      };
}

// ============================================================================
// CONSTANTS
// ============================================================================

const _WOOT_PREFIX = 'chatwoot-widget:';

class _PostMessageEvents {
  static const SET_LOCALE = 'set-locale';
  static const SET_CUSTOM_ATTRIBUTES = 'set-custom-attributes';
  static const SET_USER = 'set-user';
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

bool _isJsonString(String string) {
  try {
    jsonDecode(string);
    return true;
  } catch (e) {
    return false;
  }
}

String _createWootPostMessage(Map<String, dynamic> object) {
  final stringfyObject = "$_WOOT_PREFIX${jsonEncode(object)}";
  final script = "window.postMessage('$stringfyObject');";
  return script;
}

String _getMessage(String data) {
  return data.replaceAll(_WOOT_PREFIX, '');
}

String _generateScripts({
  _ChatwootUser? user,
  String? locale,
  dynamic customAttributes,
}) {
  String script = '';
  if (user != null) {
    final userObject = {
      "event": _PostMessageEvents.SET_USER,
      "identifier": user.identifier,
      "user": user.toJson(),
    };
    script += _createWootPostMessage(userObject);
  }
  if (locale != null) {
    final localeObject = {
      "event": _PostMessageEvents.SET_LOCALE,
      "locale": locale
    };
    script += _createWootPostMessage(localeObject);
  }
  if (customAttributes != null) {
    final attributeObject = {
      "event": _PostMessageEvents.SET_CUSTOM_ATTRIBUTES,
      "customAttributes": customAttributes,
    };
    script += _createWootPostMessage(attributeObject);
  }
  return script;
}

// ============================================================================
// SECURE STORAGE HELPER
// ============================================================================

const _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);
final _secureStorage = FlutterSecureStorage(aOptions: _androidOptions);
const _cookieKey = 'cwCookie';

class _StoreHelper {
  static Future<String> getCookie() async {
    final cookie = await _secureStorage.read(key: _cookieKey);
    return cookie ?? "";
  }

  static Future<void> storeCookie(String value) async {
    await _secureStorage.write(key: _cookieKey, value: value);
  }
}

// ============================================================================
// MAIN FLUTTERFLOW WIDGET
// ============================================================================

class VivaHelpDesk extends StatefulWidget {
  const VivaHelpDesk({
    super.key,
    this.width,
    this.height,
    required this.websiteToken,
    required this.baseUrl,
    this.userIdentifier,
    this.userName,
    this.userEmail,
    this.userAvatarUrl,
    this.tenantKey,
    this.pushToken,
    this.locale,
    this.customAttributes,
    required this.showHeader,
    required this.headerTitle,
    this.headerBackgroundColor,
    this.headerTextColor,
    this.isDark,
    this.showCloseButton,
  });

  /// Widget dimensions (FlutterFlow requirement)
  final double? width;
  final double? height;

  /// Website channel token from Chatwoot
  final String websiteToken;

  /// Base URL for Chatwoot instance (e.g., https://app.chatwoot.com)
  final String baseUrl;

  /// Custom user identifier for tracking
  final String? userIdentifier;

  /// User's display name
  final String? userName;

  /// User's email address
  final String? userEmail;

  /// User's avatar/profile picture URL
  final String? userAvatarUrl;

  /// Tenant key for multi-tenant setups
  final String? tenantKey;

  /// Push notification token
  final String? pushToken;

  /// User locale/language (default: "en")
  final String? locale;

  /// Custom attributes to pass to Chatwoot
  final dynamic customAttributes;

  /// Whether to show the header bar
  final bool showHeader;

  /// Title text for the header
  final String headerTitle;

  /// Background color for the header
  final Color? headerBackgroundColor;

  /// Text color for the header
  final Color? headerTextColor;

  /// Dark mode toggle
  final bool? isDark;

  /// Whether to show close button in chat widget
  final bool? showCloseButton;

  @override
  State<VivaHelpDesk> createState() => _VivaHelpDeskState();
}

class _VivaHelpDeskState extends State<VivaHelpDesk> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  late final String _widgetUrl;
  late final String _injectedJavaScript;
  late final _ChatwootUser? _user;

  @override
  void initState() {
    super.initState();
    _initializeWidget();
  }

  void _initializeWidget() {
    // Build user object if user data is provided
    if (widget.userIdentifier != null ||
        widget.userName != null ||
        widget.userEmail != null) {
      _user = _ChatwootUser(
        identifier: widget.userIdentifier,
        name: widget.userName,
        email: widget.userEmail,
        avatarUrl: widget.userAvatarUrl,
        customAttributes: widget.customAttributes,
      );
    } else {
      _user = null;
    }

    // Build widget URL
    final locale = widget.locale ?? "en";
    _widgetUrl =
        "${widget.baseUrl}/widget?website_token=${widget.websiteToken}&locale=$locale";

    // Generate JavaScript for user/locale initialization
    _injectedJavaScript = _generateScripts(
      user: _user,
      locale: locale,
      customAttributes: widget.customAttributes,
    );

    // Initialize WebView after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setupWebView();
    });
  }

  Future<void> _setupWebView() async {
    try {
      String webviewUrl = _widgetUrl;

      // Check for existing conversation cookie
      final cwCookie = await _StoreHelper.getCookie();
      if (cwCookie.isNotEmpty) {
        webviewUrl = "$webviewUrl&cw_conversation=$cwCookie";
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(
            widget.isDark == true ? Colors.black : Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Loading progress
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _errorMessage = 'Error loading chat: ${error.description}';
                  _isLoading = false;
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow all navigation within the webview
              return NavigationDecision.navigate;
            },
          ),
        )
        ..addJavaScriptChannel(
          "ReactNativeWebView",
          onMessageReceived: (JavaScriptMessage jsMessage) {
            debugPrint("Chatwoot message received: ${jsMessage.message}");
            final message = _getMessage(jsMessage.message);
            if (_isJsonString(message)) {
              final parsedMessage = jsonDecode(message);
              final eventType = parsedMessage["event"];
              final type = parsedMessage["type"];

              if (eventType == 'loaded') {
                // Extract and store auth token
                final authToken = parsedMessage["config"]?["authToken"];
                if (authToken != null) {
                  _StoreHelper.storeCookie(authToken);
                }
                // Inject user initialization script
                _controller?.runJavaScript(_injectedJavaScript);
              }

              if (type == 'close-widget' && (widget.showCloseButton ?? true)) {
                // Handle close widget event - can be customized
                debugPrint("Close widget requested");
              }
            }
          },
        )
        ..loadRequest(Uri.parse(webviewUrl));

      // Platform-specific configurations
      if (Platform.isAndroid) {
        // Android-specific setup
        // File selector can be added here if needed
      }

      if (Platform.isIOS) {
        // iOS-specific configuration for better Chatwoot WebView compatibility
        final wkWebViewController =
            controller.platform as WebKitWebViewController;
        wkWebViewController.setUserAgent(
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 ChatwootFlutterSDK/0.1.0');
      }

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize chat: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.isDark == true ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header (optional)
          if (widget.showHeader) _buildHeader(),

          // Chat WebView
          Expanded(
            child: _buildChatContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final headerBgColor = widget.headerBackgroundColor ??
        (widget.isDark == true ? Colors.grey[900] : Colors.blue);
    final headerTxtColor = widget.headerTextColor ?? Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: headerBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chat icon
          Icon(
            Icons.chat_bubble_outline,
            color: headerTxtColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              widget.headerTitle,
              style: TextStyle(
                color: headerTxtColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Close button (if enabled)
          if (widget.showCloseButton ?? false)
            IconButton(
              icon: Icon(
                Icons.close,
                color: headerTxtColor,
                size: 24,
              ),
              onPressed: () {
                // Handle close - can navigate back or trigger callback
                Navigator.of(context).maybePop();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark == true ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  _setupWebView();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return Center(
        child: CircularProgressIndicator(
          color: widget.headerBackgroundColor ?? Colors.blue,
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          Container(
            color: widget.isDark == true
                ? Colors.black.withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
            child: Center(
              child: CircularProgressIndicator(
                color: widget.headerBackgroundColor ?? Colors.blue,
              ),
            ),
          ),
      ],
    );
  }
}
