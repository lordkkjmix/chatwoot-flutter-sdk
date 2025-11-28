// Web implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

void registerChatwootView(String viewType, String htmlContent) {
  // Register the view factory
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = htmlContent
        ..allow = 'microphone; camera';
      return iframe;
    },
  );
}

Widget buildChatwootWebView(String viewType) {
  return HtmlElementView(viewType: viewType);
}
