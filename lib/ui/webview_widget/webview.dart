import 'dart:convert';
import 'dart:io';

import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_flutter_sdk/ui/webview_widget/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

///Chatwoot webview widget
/// {@category FlutterClientSdk}
class Webview extends StatefulWidget {
  /// Url for Chatwoot widget in webview
  late final String widgetUrl;

  /// Base URL for Chatwoot instance
  late final String baseUrl;

  /// Chatwoot user & locale initialisation script
  late final String injectedJavaScript;

  /// See [ChatwootWidget.closeWidget]
  final void Function()? closeWidget;

  /// See [ChatwootWidget.onAttachFile]
  final Future<List<String>> Function()? onAttachFile;

  /// See [ChatwootWidget.onLoadStarted]
  final void Function()? onLoadStarted;

  /// See [ChatwootWidget.onLoadProgress]
  final void Function(int)? onLoadProgress;

  /// See [ChatwootWidget.onLoadCompleted]
  final void Function()? onLoadCompleted;

  /// Whether to show the close button in the chat widget
  final bool showCloseButton;

  Webview(
      {Key? key,
      required String websiteToken,
      required String baseUrl,
      ChatwootUser? user,
      String locale = "en",
      customAttributes,
      this.closeWidget,
      this.onAttachFile,
      this.onLoadStarted,
      this.onLoadProgress,
      this.onLoadCompleted,
      this.showCloseButton = false})
      : super(key: key) {
    this.baseUrl = baseUrl;
    widgetUrl =
        "${baseUrl}/widget?website_token=${websiteToken}&locale=${locale}";

    injectedJavaScript = generateScripts(
        user: user, locale: locale, customAttributes: customAttributes);
  }

  @override
  _WebviewState createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  WebViewController? _controller;
  @override
  void initState() {
    super.initState();
    //_requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String webviewUrl = widget.widgetUrl;
      final cwCookie = await StoreHelper.getCookie();
      if (cwCookie.isNotEmpty) {
        webviewUrl = "${webviewUrl}&cw_conversation=${cwCookie}";
      }
      setState(() {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // Update loading bar.
                widget.onLoadProgress?.call(progress);
              },
              onPageStarted: (String url) {
                widget.onLoadStarted?.call();
              },
              onPageFinished: (String url) async {
                widget.onLoadCompleted?.call();
              },
              onWebResourceError: (WebResourceError error) {},
              onNavigationRequest: (NavigationRequest request) {
                // Allow all navigation within the webview to keep everything contained
                return NavigationDecision.navigate;
              },
            ),
          )
          ..addJavaScriptChannel("ReactNativeWebView",
              onMessageReceived: (JavaScriptMessage jsMessage) {
            debugPrint("Chatwoot message received: ${jsMessage.message}");
            final message = getMessage(jsMessage.message);
            if (isJsonString(message)) {
              final parsedMessage = jsonDecode(message);
              final eventType = parsedMessage["event"];
              final type = parsedMessage["type"];
              if (eventType == 'loaded') {
                final authToken = parsedMessage["config"]["authToken"];
                StoreHelper.storeCookie(authToken);
                _controller?.runJavaScript(widget.injectedJavaScript);
              }
              if (type == 'close-widget' && widget.showCloseButton) {
                widget.closeWidget?.call();
              }
            }
          })
          ..loadRequest(Uri.parse(webviewUrl));

        // Platform-specific configurations
        if (Platform.isAndroid && widget.onAttachFile != null) {
          final androidController = _controller!.platform
              as webview_flutter_android.AndroidWebViewController;
          //androidController.setOnShowFileSelector(_androidFilePicker);

          androidController
              .setOnShowFileSelector((_) => widget.onAttachFile!.call());
        }

        if (Platform.isIOS) {
          // iOS-specific configuration for better Chatwoot WebView compatibility
          final wkWebViewController =
              _controller!.platform as WebKitWebViewController;

          // Set user agent to ensure proper Chatwoot rendering
          wkWebViewController.setUserAgent(
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 ChatwootFlutterSDK/0.1.0');
        }
      });
    });
  }

  // helper to request permissions
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.photos.request();
    await Permission.phone.request();
  }

  Future<List<String>> _androidFilePicker(webview_flutter_android.FileSelectorParams params) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type:FileType.any);

    if (result != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      final filePath1 = (await getTemporaryDirectory()).uri.resolve(fileName);
      final file = await File.fromUri(filePath1).create(recursive: true);
      await file.writeAsBytes(await File(filePath).readAsBytes(), flush: true);

      return [file.uri.toString()];
    }

    return [];
  }


  @override
  Widget build(BuildContext context) {
    return _controller != null
        ? WebViewWidget(controller: _controller!)
        : SizedBox();
  }
}
