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
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// Conditional imports for web
import 'viva_help_desk_stub.dart'
    if (dart.library.html) 'viva_help_desk_web.dart' as platform;

// Mobile imports
import 'package:webview_flutter/webview_flutter.dart';

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
  // For mobile
  WebViewController? _mobileController;

  // For web
  String? _webViewType;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWidget();
  }

  void _initializeWidget() {
    if (kIsWeb) {
      _setupWeb();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setupMobile());
    }
  }

  // ============================================================================
  // WEB IMPLEMENTATION
  // ============================================================================

  void _setupWeb() {
    final viewType = 'chatwoot-widget-${Random().nextInt(1000000)}';
    final html = _generateWebHtml();

    print('DEBUG Web: Registering view type: $viewType');
    print('DEBUG Web: HTML length: ${html.length}');

    platform.registerChatwootView(viewType, html);

    if (mounted) {
      setState(() {
        _webViewType = viewType;
        _isLoading = false;
      });
    }
  }

  String _generateWebHtml() {
    final baseUrl = widget.baseUrl;
    final websiteToken = widget.websiteToken;
    final locale = widget.locale ?? 'en';
    final isDark = widget.isDark == true;

    // User data
    final userId = _escapeJs(widget.userIdentifier ?? '');
    final userName = _escapeJs(widget.userName ?? '');
    final userEmail = _escapeJs(widget.userEmail ?? '');
    final userAvatar = _escapeJs(widget.userAvatarUrl ?? '');

    // Custom attributes
    final tenant = _escapeJs(widget.tenantKey ?? '');
    final pushToken = _escapeJs(widget.pushToken ?? '');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: ${isDark ? '#000' : '#fff'};
    }
    .woot-widget-holder {
      width: 100% !important;
      height: 100% !important;
      max-height: 100% !important;
      bottom: 0 !important;
      right: 0 !important;
    }
    .woot-widget-bubble, .woot--bubble-holder {
      display: none !important;
    }
    .woot-widget-holder iframe {
      width: 100% !important;
      height: 100% !important;
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
        window.chatwootSDK.run({
          websiteToken: '$websiteToken',
          baseUrl: BASE_URL
        });

        // Poll for \$chatwoot like React example
        var attempts = 0;
        var maxAttempts = 60;

        var waitForChat = setInterval(function() {
          attempts++;
          var chatwoot = window.\$chatwoot;

          if (chatwoot) {
            console.log('VivaHelpDesk: \$chatwoot ready after ' + attempts + ' attempts');

            // Set user
            ${userId.isNotEmpty ? '''
            try {
              chatwoot.setUser('$userId', {
                ${userName.isNotEmpty ? "name: '$userName'," : ''}
                ${userEmail.isNotEmpty ? "email: '$userEmail'," : ''}
                ${userAvatar.isNotEmpty ? "avatar_url: '$userAvatar'," : ''}
              });
              console.log('VivaHelpDesk: setUser success');
            } catch(e) {
              console.error('VivaHelpDesk: setUser error:', e);
            }
            ''' : ''}

            // Set custom attributes
            ${(tenant.isNotEmpty || pushToken.isNotEmpty) ? '''
            try {
              chatwoot.setCustomAttributes({
                ${tenant.isNotEmpty ? "tenant: '$tenant'," : ''}
                ${pushToken.isNotEmpty ? "pushToken: '$pushToken'," : ''}
              });
              console.log('VivaHelpDesk: setCustomAttributes success');
            } catch(e) {
              console.error('VivaHelpDesk: setCustomAttributes error:', e);
            }
            ''' : ''}

            // Set locale
            try {
              chatwoot.setLocale('$locale');
              console.log('VivaHelpDesk: setLocale success');
            } catch(e) {
              console.error('VivaHelpDesk: setLocale error:', e);
            }

            // Toggle to show widget
            try {
              chatwoot.toggle('open');
              console.log('VivaHelpDesk: toggle open success');
            } catch(e) {
              console.error('VivaHelpDesk: toggle error:', e);
            }

            clearInterval(waitForChat);
          } else if (attempts >= maxAttempts) {
            console.warn('VivaHelpDesk: timeout waiting for \$chatwoot');
            clearInterval(waitForChat);
          }
        }, 500);
      };
    })(document, "script");
  </script>
</body>
</html>
''';
  }

  // ============================================================================
  // MOBILE IMPLEMENTATION
  // ============================================================================

  Future<void> _setupMobile() async {
    try {
      String url = _buildMobileUrl();
      print('DEBUG Mobile: URL = $url');

      final cookie = await _StoreHelper.getCookie();
      if (cookie.isNotEmpty) {
        url = "$url&cw_conversation=$cookie";
      }

      final controller = WebViewController();

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
              // Inject user data
              final script = _generateMobileScript();
              if (script.isNotEmpty) {
                _mobileController?.runJavaScript(script);
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
          print('DEBUG Mobile: Page finished');
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

      if (mounted) setState(() => _mobileController = controller);
    } catch (e) {
      print('DEBUG Mobile: Error = $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _buildMobileUrl() {
    final locale = widget.locale ?? "en";
    final params = <String, String>{
      'website_token': widget.websiteToken,
      'locale': locale,
    };
    final uri =
        Uri.parse('${widget.baseUrl}/widget').replace(queryParameters: params);
    return uri.toString();
  }

  String _generateMobileScript() {
    final scripts = <String>[];

    if (widget.userIdentifier != null) {
      final userData = <String, dynamic>{
        'identifier': widget.userIdentifier,
      };
      if (widget.userName != null) userData['name'] = widget.userName;
      if (widget.userEmail != null) userData['email'] = widget.userEmail;
      if (widget.userAvatarUrl != null)
        userData['avatar_url'] = widget.userAvatarUrl;

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
    if (widget.tenantKey != null) customAttrs['tenant'] = widget.tenantKey;
    if (widget.pushToken != null) customAttrs['pushToken'] = widget.pushToken;

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
  // HELPERS
  // ============================================================================

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
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
              style: TextStyle(
                  color: txt, fontSize: 18, fontWeight: FontWeight.w600),
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
                _initializeWidget();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    // Web content
    if (kIsWeb) {
      if (_webViewType == null) {
        return Center(
          child: CircularProgressIndicator(
            color: widget.headerBackgroundColor ?? Colors.blue,
          ),
        );
      }
      return platform.buildChatwootWebView(_webViewType!);
    }

    // Mobile content
    if (_mobileController == null) {
      return Center(
        child: CircularProgressIndicator(
          color: widget.headerBackgroundColor ?? Colors.blue,
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _mobileController!),
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
