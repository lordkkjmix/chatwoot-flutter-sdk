// FlutterFlow Custom Widget - VivaHelpDesk (Chatwoot Chat)
//
// DEPENDENCIES (add to pubspec.yaml):
//   webview_flutter: ^4.13.0
//   webview_flutter_android: ^4.7.0
//   webview_flutter_wkwebview: ^3.22.0
//   webview_flutter_web: ^0.2.3+4
//   shared_preferences: (already included in FlutterFlow)
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
import 'package:webview_flutter_web/webview_flutter_web.dart';

// ============================================================================
// CHATWOOT USER MODEL
// ============================================================================

class _ChatwootUser {
  final String? identifier;
  final String? name;
  final String? email;
  final String? avatarUrl;

  _ChatwootUser({
    this.identifier,
    this.name,
    this.email,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        if (identifier != null) 'identifier': identifier,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
}

// ============================================================================
// CONSTANTS & UTILITIES
// ============================================================================

const _WOOT_PREFIX = 'chatwoot-widget:';

String _createWootPostMessage(Map<String, dynamic> object) {
  return "window.postMessage('$_WOOT_PREFIX${jsonEncode(object)}');";
}

String _getMessage(String data) => data.replaceAll(_WOOT_PREFIX, '');

bool _isJsonString(String s) {
  try {
    jsonDecode(s);
    return true;
  } catch (_) {
    return false;
  }
}

String _generateScripts({
  _ChatwootUser? user,
  String? locale,
  Map<String, dynamic>? customAttributes,
}) {
  String script = '';
  if (user != null) {
    script += _createWootPostMessage({
      "event": "set-user",
      "identifier": user.identifier,
      "user": user.toJson(),
    });
  }
  if (locale != null) {
    script += _createWootPostMessage({"event": "set-locale", "locale": locale});
  }
  if (customAttributes != null) {
    script += _createWootPostMessage({
      "event": "set-custom-attributes",
      "customAttributes": customAttributes,
    });
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
      return prefs.getString(_cookieKey) ?? "";
    } catch (_) {
      return "";
    }
  }

  static Future<void> storeCookie(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieKey, value);
    } catch (_) {}
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
  static bool _webPlatformRegistered = false;

  late final String _widgetUrl;
  late final String _injectedJavaScript;

  @override
  void initState() {
    super.initState();
    _initializeWidget();
  }

  void _initializeWidget() {
    // Register web platform ONCE
    if (kIsWeb && !_webPlatformRegistered) {
      WebViewPlatform.instance = WebWebViewPlatform();
      _webPlatformRegistered = true;
    }

    // Build custom attributes
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

    // Build user
    _ChatwootUser? user;
    if (widget.userIdentifier != null ||
        widget.userName != null ||
        widget.userEmail != null) {
      user = _ChatwootUser(
        identifier: widget.userIdentifier,
        name: widget.userName,
        email: widget.userEmail,
        avatarUrl: widget.userAvatarUrl,
      );
    }

    // Build URL
    final locale = widget.locale ?? "en";
    _widgetUrl =
        "${widget.baseUrl}/widget?website_token=${widget.websiteToken}&locale=$locale";

    // Generate JS
    _injectedJavaScript = _generateScripts(
      user: user,
      locale: locale,
      customAttributes: customAttributes,
    );

    // Setup WebView
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupWebView());
  }

  Future<void> _setupWebView() async {
    try {
      String url = _widgetUrl;
      final cookie = await _StoreHelper.getCookie();
      if (cookie.isNotEmpty) {
        url = "$url&cw_conversation=$cookie";
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.isDark == true ? Colors.black : Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            // Inject scripts on web after page load
            if (kIsWeb && _injectedJavaScript.isNotEmpty) {
              _controller?.runJavaScript(_injectedJavaScript);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Error: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ));

      // JS channel only for mobile
      if (!kIsWeb) {
        controller.addJavaScriptChannel(
          "ReactNativeWebView",
          onMessageReceived: (msg) {
            final message = _getMessage(msg.message);
            if (_isJsonString(message)) {
              final parsed = jsonDecode(message);
              if (parsed["event"] == 'loaded') {
                final token = parsed["config"]?["authToken"];
                if (token != null) _StoreHelper.storeCookie(token);
                _controller?.runJavaScript(_injectedJavaScript);
              }
            }
          },
        );
      }

      controller.loadRequest(Uri.parse(url));

      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed: $e';
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
    final bg = widget.headerBackgroundColor ??
        (widget.isDark == true ? Colors.grey[900] : Colors.blue);
    final txt = widget.headerTextColor ?? Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bg,
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: txt, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.headerTitle,
              style: TextStyle(color: txt, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.showCloseButton ?? false)
            IconButton(
              icon: Icon(Icons.close, color: txt),
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
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
            color: (widget.isDark == true ? Colors.black : Colors.white)
                .withOpacity(0.7),
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
