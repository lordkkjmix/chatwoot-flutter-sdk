// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

void registerChatwootView(String viewType, String html) {
  // No-op on non-web platforms
}

Widget buildChatwootWebView(String viewType) {
  return const Center(child: Text('Web only'));
}
