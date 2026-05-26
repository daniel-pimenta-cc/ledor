import 'package:flutter/widgets.dart';

abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
}

enum DeviceType { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  // Use the granular sizeOf/orientationOf helpers instead of
  // `MediaQuery.of(this)`. `.of` registers a dependency on the ENTIRE
  // MediaQueryData, so a viewInsets change (e.g. IME animating up)
  // would rebuild every widget that touches isTablet/deviceType/etc.
  // The granular variants only listen to the aspect they read.
  Size get _size => MediaQuery.sizeOf(this);
  Orientation get _orientation => MediaQuery.orientationOf(this);

  bool get isTablet => _size.shortestSide >= Breakpoints.compact;
  bool get isLandscape => _orientation == Orientation.landscape;

  DeviceType get deviceType {
    final w = _size.width;
    if (w >= Breakpoints.medium) return DeviceType.expanded;
    if (w >= Breakpoints.compact) return DeviceType.medium;
    return DeviceType.compact;
  }
}

