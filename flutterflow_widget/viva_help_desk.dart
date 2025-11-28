// FlutterFlow Custom Widget - VivaHelpDesk (Chatwoot Chat)
//
// DEPENDENCIES (add to pubspec.yaml):
//   webview_flutter: ^4.13.0
//   webview_flutter_android: ^4.7.0
//   webview_flutter_wkwebview: ^3.22.0
//   shared_preferences: (already included in FlutterFlow)
//
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/supabase/supabase.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart';
import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ============================================================================
// STORAGE HELPER
// ============================================================================

const _cookieKey = 'chatwoot_cw_cookie';
const _WOOT_PREFIX = 'chatwoot-widget:';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupWebView());
  }

  // ============================================================================
  // URL BUILDERS
  // ============================================================================

  /// Build widget URL for mobile (standard approach)
  String _buildMobileUrl() {
    final locale = widget.locale ?? "en";
    final params = <String, String>{
      'website_token': widget.websiteToken,
      'locale': locale,
    };
    return Uri.parse('${widget.baseUrl}/widget')
        .replace(queryParameters: params)
        .toString();
  }

  /// Build data URL with embedded HTML for web
  /// This embeds the Chatwoot SDK directly with all user data
  Uri _buildWebDataUrl() {
    final html = _generateEmbeddedHtml();
    return Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    );
  }

  // ============================================================================
  // HTML GENERATION FOR WEB
  // ============================================================================

  String _generateEmbeddedHtml() {
    final baseUrl = widget.baseUrl;
    final websiteToken = widget.websiteToken;
    final locale = widget.locale ?? 'en';
    final isDark = widget.isDark == true;

    // Escape for JS
    final userId = _escapeJs(widget.userIdentifier ?? '');
    final userName = _escapeJs(widget.userName ?? '');
    final userEmail = _escapeJs(widget.userEmail ?? '');
    final userAvatar = _escapeJs(widget.userAvatarUrl ?? '');
    final tenant = _escapeJs(widget.tenantKey ?? '');
    final pushToken = _escapeJs(widget.pushToken ?? '');

    // Build user data object parts
    final userDataParts = <String>[];
    if (userName.isNotEmpty) userDataParts.add("name: '$userName'");
    if (userEmail.isNotEmpty) userDataParts.add("email: '$userEmail'");
    if (userAvatar.isNotEmpty) userDataParts.add("avatar_url: '$userAvatar'");

    // Build custom attributes
    final customAttrParts = <String>[];
    if (tenant.isNotEmpty) customAttrParts.add("tenant: '$tenant'");
    if (pushToken.isNotEmpty) customAttrParts.add("pushToken: '$pushToken'");

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%;
      overflow: hidden;
      background: ${isDark ? '#1a1a1a' : '#ffffff'};
    }
    .woot-widget-holder {
      width: 100% !important; height: 100% !important;
      max-height: 100% !important;
      bottom: 0 !important; right: 0 !important;
      position: fixed !important;
    }
    .woot-widget-bubble, .woot--bubble-holder { display: none !important; }
    .woot-widget-holder iframe {
      width: 100% !important; height: 100% !important;
      max-height: 100% !important;
    }
  </style>
</head>
<body>
<script>
  window.chatwootSettings = {
    position: 'right',
    type: 'expanded_bubble',
    launcherTitle: 'Chat',
    darkMode: '${isDark ? 'auto' : 'light'}',
    locale: '$locale'
  };

  (function(d, t) {
    var BASE_URL = "$baseUrl";
    var g = d.createElement(t), s = d.getElementsByTagName(t)[0];
    g.src = BASE_URL + "/packs/js/sdk.js";
    g.defer = true;
    g.async = true;
    s.parentNode.insertBefore(g, s);

    g.onload = function() {
      // Try both SDK names (vivahelpdeskSDK for custom servers, chatwootSDK for standard)
      var sdk = window.vivahelpdeskSDK || window.chatwootSDK;
      if (sdk) {
        sdk.run({
          websiteToken: '$websiteToken',
          baseUrl: BASE_URL
        });
      } else {
        console.error('VivaHelpDesk: SDK not found');
        return;
      }

      var attempts = 0;
      var maxAttempts = 60;

      var waitForChat = setInterval(function() {
        attempts++;
        var cw = window.\$chatwoot;

        if (cw) {
          console.log('VivaHelpDesk: \$chatwoot ready');

          ${userId.isNotEmpty ? '''
          try {
            cw.setUser('$userId', { ${userDataParts.join(', ')} });
            console.log('VivaHelpDesk: setUser OK');
          } catch(e) { console.error('setUser error:', e); }
          ''' : ''}

          ${customAttrParts.isNotEmpty ? '''
          try {
            cw.setCustomAttributes({ ${customAttrParts.join(', ')} });
            console.log('VivaHelpDesk: setCustomAttributes OK');
          } catch(e) { console.error('setCustomAttributes error:', e); }
          ''' : ''}

          try {
            cw.setLocale('$locale');
          } catch(e) {}

          try {
            cw.toggle('open');
          } catch(e) {}

          clearInterval(waitForChat);
        } else if (attempts >= maxAttempts) {
          console.warn('VivaHelpDesk: timeout');
          clearInterval(waitForChat);
        }
      }, 500);
    };
  })(document, "script");
</script>
</body>
</html>''';
  }

  // ============================================================================
  // SCRIPTS FOR MOBILE
  // ============================================================================

  String _generateMobileScript() {
    final scripts = <String>[];

    if (widget.userIdentifier != null && widget.userIdentifier!.isNotEmpty) {
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

    if (widget.locale != null) {
      final msg = jsonEncode({'event': 'set-locale', 'locale': widget.locale});
      scripts.add("window.postMessage('$_WOOT_PREFIX$msg');");
    }

    final customAttrs = <String, dynamic>{};
    if (widget.tenantKey != null && widget.tenantKey!.isNotEmpty) {
      customAttrs['tenant'] = widget.tenantKey;
    }
    if (widget.pushToken != null && widget.pushToken!.isNotEmpty) {
      customAttrs['pushToken'] = widget.pushToken;
    }

    if (customAttrs.isNotEmpty) {
      final msg = jsonEncode({
        'event': 'set-custom-attributes',
        'customAttributes': customAttrs,
      });
      scripts.add("window.postMessage('$_WOOT_PREFIX$msg');");
    }

    return scripts.join('\n');
  }

  // ============================================================================
  // WEBVIEW SETUP
  // ============================================================================

  Future<void> _setupWebView() async {
    try {
      final controller = WebViewController();

      // Different setup for web vs mobile
      if (kIsWeb) {
        print('DEBUG: Setting up for WEB platform');
        // On web, load data URL with embedded HTML
        final dataUrl = _buildWebDataUrl();
        print('DEBUG: Data URL length: ${dataUrl.toString().length}');
        controller.loadRequest(dataUrl);

        // Hide loading after delay (no NavigationDelegate on web)
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isLoading = false);
        });
      } else {
        print('DEBUG: Setting up for MOBILE platform');
        // Mobile setup with full features
        String url = _buildMobileUrl();
        final cookie = await _StoreHelper.getCookie();
        if (cookie.isNotEmpty) {
          url = "$url&cw_conversation=$cookie";
        }
        print('DEBUG: Mobile URL: $url');

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
                final script = _generateMobileScript();
                if (script.isNotEmpty) {
                  _controller?.runJavaScript(script);
                }
              }
            }
          },
        );

        controller.setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            print('DEBUG: Mobile page finished');
            if (mounted) setState(() => _isLoading = false);
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
      }

      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      print('DEBUG: Setup error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  // ============================================================================
  // BUILD
  // ============================================================================

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                  _controller = null;
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
                .withOpacity(0.8),
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
