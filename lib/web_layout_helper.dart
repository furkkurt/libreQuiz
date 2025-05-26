import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

class WebLayoutHelper {
  // Checks if we're on web
  static bool get isWeb => identical(0, 0.0) || ui.PlatformDispatcher.instance.views.first.physicalSize.isEmpty;
  
  // Returns a responsive width based on screen size
  static double getResponsiveWidth(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 1100; // Large desktop
    } else if (screenWidth > 800) {
      return screenWidth * 0.8; // Desktop/tablet
    } else {
      return screenWidth * 0.95; // Mobile
    }
  }
  
  // Returns different paddings for web/mobile
  static EdgeInsets getContentPadding(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 800) {
      return const EdgeInsets.all(32.0); // Increased desktop padding
    } else {
      return const EdgeInsets.all(16.0); // Mobile padding
    }
  }
  
  // Get a font size multiplier for web
  static double getFontSizeMultiplier(BuildContext context) {
    if (!isWeb) return 1.0;
    
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 1.3; // Reduced from 2.0
    } else if (screenWidth > 800) {
      return 1.2; // Reduced from 1.7
    } else {
      return 1.1; // Reduced from 1.4
    }
  }
  
  // Get button size multiplier for web
  static double getButtonSizeMultiplier(BuildContext context) {
    if (!isWeb) return 1.0;
    
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1000) {
      return 1.2; // Reduced from 2.0
    } else {
      return 1.1; // Reduced from 1.6
    }
  }
  
  // Wraps content in responsive container for web
  static Widget wrapResponsive(BuildContext context, Widget child) {
    if (!isWeb) return child;
    
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: getResponsiveWidth(context),
        ),
        child: child,
      ),
    );
  }
}