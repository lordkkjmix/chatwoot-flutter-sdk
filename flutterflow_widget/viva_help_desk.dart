// FlutterFlow Custom Widget - VivaHelpDesk (Chatwoot Chat)
//
// DEPENDENCIES (add to pubspec.yaml):
//   webview_flutter: ^4.13.0
//   webview_flutter_android: ^4.7.0
//   webview_flutter_wkwebview: ^3.22.0
//   shared_preferences: (already included in FlutterFlow)
//
// NOTE: WebView works on iOS/Android only. On Web shows a message.
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ============================================================================
// CHATWOOT USER MODEL
// ============================================================================

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
// STORAGE HELPER
// ============================================================================

const _cookieKey = 'chatwoot_cw_cookie';

class _StoreHelper {
  static Future<String> getCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString(_cookieKey);
      return cookie ?? "";
    } catch (e) {
      return "";
    }
  }

  static Future<void> storeCookie(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieKey, value);
    } catch (e) {
      // ignore
    }
  }
}

// ============================================================================
// MAIN WIDGET
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
    required this.showHeader,
    required this.headerTitle,
    this.headerBackgroundColor,
    this.headerTextColor,
    this.isDark,
    this.showCloseButton,
  });

  final double? width;
  final double? height;
  final String websiteToken;
  final String baseUrl;
  final String? userIdentifier;
  final String? userName;
  final String? userEmail;
  final String? userAvatarUrl;
  final String? tenantKey;
  final String? pushToken;
  final String? locale;
  final bool showHeader;
  final String headerTitle;
  final Color? headerBackgroundColor;
  final Color? headerTextColor;
  final bool? isDark;
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
    // Build custom attributes from tenantKey and pushToken
    Map<String, dynamic>? customAttributes;
    if (widget.tenantKey != null || widget.pushToken != null) {
      customAttributes = {};
      if (widget.tenantKey != null) {
        customAttributes['tenant_key'] = widget.tenantKey;
      }
      if (widget.pushToken != null) {
        customAttributes['push_token'] = widget.pushToken;
      }
    }

    // Build user object if user data is provided
    if (widget.userIdentifier != null ||
        widget.userName != null ||
        widget.userEmail != null) {
      _user = _ChatwootUser(
        identifier: widget.userIdentifier,
        name: widget.userName,
        email: widget.userEmail,
        avatarUrl: widget.userAvatarUrl,
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
      customAttributes: customAttributes,
    );

    // On web - don't initialize WebView (not supported)
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Initialize WebView after frame is rendered (mobile only)
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
            onPageStarted: (String url) {
              if (mounted) {
                setState(() => _isLoading = true);
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _errorMessage = 'Error: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          "ReactNativeWebView",
          onMessageReceived: (JavaScriptMessage jsMessage) {
            final message = _getMessage(jsMessage.message);
            if (_isJsonString(message)) {
              final parsedMessage = jsonDecode(message);
              final eventType = parsedMessage["event"];

              if (eventType == 'loaded') {
                final authToken = parsedMessage["config"]?["authToken"];
                if (authToken != null) {
                  _StoreHelper.storeCookie(authToken);
                }
                _controller?.runJavaScript(_injectedJavaScript);
              }
            }
          },
        )
        ..loadRequest(Uri.parse(webviewUrl));

      if (mounted) {
        setState(() => _controller = controller);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
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
          if (widget.showHeader) _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bgColor = widget.headerBackgroundColor ??
        (widget.isDark == true ? Colors.grey[900] : Colors.blue);
    final txtColor = widget.headerTextColor ?? Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: txtColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.headerTitle,
              style: TextStyle(
                color: txtColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.showCloseButton ?? false)
            IconButton(
              icon: Icon(Icons.close, color: txtColor),
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Web platform - show message
    if (kIsWeb) {
      return _buildWebMessage();
    }

    // Error state
    if (_errorMessage != null) {
      return _buildError();
    }

    // Loading state
    if (_controller == null) {
      return _buildLoading();
    }

    // WebView
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading) _buildLoading(),
      ],
    );
  }

  Widget _buildWebMessage() {
    final txtColor = widget.isDark == true ? Colors.white70 : Colors.black54;
    final accent = widget.headerBackgroundColor ?? Colors.blue;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 64, color: accent),
            const SizedBox(height: 24),
            Text(
              'Чат доступен в мобильном приложении',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark == true ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Для тестирования используйте Test Mode на реальном устройстве iOS или Android',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: txtColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isLoading = true;
              });
              _setupWebView();
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: (widget.isDark == true ? Colors.black : Colors.white)
          .withOpacity(0.7),
      child: Center(
        child: CircularProgressIndicator(
          color: widget.headerBackgroundColor ?? Colors.blue,
        ),
      ),
    );
  }
}
