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
// CONSTANTS
// ============================================================================

const _WOOT_PREFIX = 'chatwoot-widget:';

String _getMessage(String data) => data.replaceAll(_WOOT_PREFIX, '');

bool _isJsonString(String s) {
  try {
    jsonDecode(s);
    return true;
  } catch (_) {
    return false;
  }
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

    // Setup WebView
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupWebView());
  }

  /// Build URL with all parameters
  String _buildWidgetUrl() {
    final locale = widget.locale ?? "en";
    final darkMode = widget.isDark == true ? "dark" : "light";

    final params = <String, String>{
      'website_token': widget.websiteToken,
      'locale': locale,
      'dark_mode': darkMode,
    };

    final uri = Uri.parse('${widget.baseUrl}/widget').replace(queryParameters: params);
    return uri.toString();
  }

  /// Generate JavaScript to set user and custom attributes using $chatwoot SDK
  String _generateChatwootScript() {
    final scripts = <String>[];

    // Set user if identifier provided
    if (widget.userIdentifier != null && widget.userIdentifier!.isNotEmpty) {
      final userData = <String, dynamic>{};
      if (widget.userName != null) userData['name'] = widget.userName;
      if (widget.userEmail != null) userData['email'] = widget.userEmail;
      if (widget.userAvatarUrl != null) userData['avatar_url'] = widget.userAvatarUrl;

      final userDataJson = jsonEncode(userData);
      scripts.add('''
        if (window.\$chatwoot && window.\$chatwoot.setUser) {
          window.\$chatwoot.setUser('${widget.userIdentifier}', $userDataJson);
        }
      ''');
    }

    // Set custom attributes
    final customAttrs = <String, dynamic>{};
    if (widget.tenantKey != null && widget.tenantKey!.isNotEmpty) {
      customAttrs['tenant_key'] = widget.tenantKey;
    }
    if (widget.pushToken != null && widget.pushToken!.isNotEmpty) {
      customAttrs['push_token'] = widget.pushToken;
    }

    if (customAttrs.isNotEmpty) {
      final attrsJson = jsonEncode(customAttrs);
      scripts.add('''
        if (window.\$chatwoot && window.\$chatwoot.setCustomAttributes) {
          window.\$chatwoot.setCustomAttributes($attrsJson);
        }
      ''');
    }

    // Set locale
    if (widget.locale != null) {
      scripts.add('''
        if (window.\$chatwoot && window.\$chatwoot.setLocale) {
          window.\$chatwoot.setLocale('${widget.locale}');
        }
      ''');
    }

    if (scripts.isEmpty) return '';

    // Wrap in chatwoot:ready event listener OR direct call if already ready
    return '''
      (function() {
        function initChatwoot() {
          ${scripts.join('\n')}
        }

        if (window.\$chatwoot) {
          initChatwoot();
        } else {
          window.addEventListener('chatwoot:ready', initChatwoot);
        }
      })();
    ''';
  }

  /// Generate postMessage script for mobile
  String _generatePostMessageScript() {
    final scripts = <String>[];

    // Set user
    if (widget.userIdentifier != null) {
      final userData = <String, dynamic>{
        'identifier': widget.userIdentifier,
      };
      if (widget.userName != null) userData['name'] = widget.userName;
      if (widget.userEmail != null) userData['email'] = widget.userEmail;
      if (widget.userAvatarUrl != null) userData['avatar_url'] = widget.userAvatarUrl;

      final msg = jsonEncode({
        'event': 'set-user',
        'identifier': widget.userIdentifier,
        'user': userData,
      });
      scripts.add("window.postMessage('$_WOOT_PREFIX$msg');");
    }

    // Set locale
    if (widget.locale != null) {
      final msg = jsonEncode({'event': 'set-locale', 'locale': widget.locale});
      scripts.add("window.postMessage('$_WOOT_PREFIX$msg');");
    }

    // Set custom attributes
    final customAttrs = <String, dynamic>{};
    if (widget.tenantKey != null) customAttrs['tenant_key'] = widget.tenantKey;
    if (widget.pushToken != null) customAttrs['push_token'] = widget.pushToken;

    if (customAttrs.isNotEmpty) {
      final msg = jsonEncode({
        'event': 'set-custom-attributes',
        'customAttributes': customAttrs,
      });
      scripts.add("window.postMessage('$_WOOT_PREFIX$msg');");
    }

    return scripts.join('\n');
  }

  Future<void> _setupWebView() async {
    try {
      String url = _buildWidgetUrl();
      print('DEBUG: Built URL with dark_mode: $url');

      // Add conversation cookie if exists
      final cookie = await _StoreHelper.getCookie();
      if (cookie.isNotEmpty) {
        url = "$url&cw_conversation=$cookie";
      }
      print('DEBUG: Final URL: $url');
      print('DEBUG: kIsWeb = $kIsWeb');

      final controller = WebViewController();

      // Mobile-only methods (not supported on web)
      if (!kIsWeb) {
        print('DEBUG: Applying mobile-only settings (setJavaScriptMode, etc.)');
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        controller.setBackgroundColor(
            widget.isDark == true ? Colors.black : Colors.white);
        controller.addJavaScriptChannel(
          "ReactNativeWebView",
          onMessageReceived: (msg) {
            final message = _getMessage(msg.message);
            if (_isJsonString(message)) {
              final parsed = jsonDecode(message);
              if (parsed["event"] == 'loaded') {
                final token = parsed["config"]?["authToken"];
                if (token != null) _StoreHelper.storeCookie(token);
                // Inject user data after widget loaded
                final script = _generatePostMessageScript();
                print('DEBUG: Mobile postMessage script: ${script.substring(0, script.length > 100 ? 100 : script.length)}...');
                if (script.isNotEmpty) {
                  _controller?.runJavaScript(script);
                }
              }
            }
          },
        );
      } else {
        print('DEBUG: Skipping mobile-only settings on web');
      }

      controller.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          print('DEBUG: Page finished loading');
          if (mounted) setState(() => _isLoading = false);

          // Inject scripts after page load
          if (kIsWeb) {
            // Use $chatwoot SDK on web
            final script = _generateChatwootScript();
            print('DEBUG: Web \$chatwoot SDK script generated (${script.length} chars)');
            if (script.isNotEmpty) {
              print('DEBUG: Injecting \$chatwoot script...');
              _controller?.runJavaScript(script);
            }
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
