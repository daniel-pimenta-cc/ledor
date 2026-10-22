import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives reader-chrome visibility during RSVP playback (focus mode).
///
/// Plain [ChangeNotifier] so the timing logic is unit-testable without
/// pumping the reader screen. The screen wires engine state and gestures
/// into it and fades the chrome from [visible].
///
/// Contract:
/// - [setActive] with true shows the chrome and arms the hide timer;
///   with false it cancels the timer and shows the chrome.
/// - [onUserInteraction] (any pointer contact while active) reveals the
///   chrome and restarts the idle timer. When the chrome was hidden, the
///   following tap is earmarked for the reveal.
/// - [handleWordTap] reports whether the word-area tap only revealed the
///   chrome (caller must then skip the play/pause toggle).
/// - [clearPendingTap] drops the earmark — drags and long-presses are
///   actions of their own and must not eat the *next* tap.
class FocusModeController extends ChangeNotifier {
  /// Idle time after which playing RSVP hides the chrome.
  final Duration hideDelay;

  Timer? _hideTimer;
  bool _active = false;
  bool _visible = true;
  bool _tapEarmarked = false;

  FocusModeController({this.hideDelay = const Duration(seconds: 3)});

  /// Whether focus rules currently apply (playing RSVP, focus enabled).
  bool get isActive => _active;

  /// Whether the chrome should be shown right now.
  bool get visible => _visible;

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _tapEarmarked = false;
    if (active) {
      _show();
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
      _show();
    }
  }

  void onUserInteraction() {
    if (!_active) return;
    final wasHidden = !_visible;
    _show();
    _tapEarmarked = wasHidden;
    _scheduleHide();
  }

  bool handleWordTap() {
    if (!_tapEarmarked) return false;
    _tapEarmarked = false;
    return true;
  }

  void clearPendingTap() => _tapEarmarked = false;

  void _show() {
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(hideDelay, () {
      if (!_active) return;
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
