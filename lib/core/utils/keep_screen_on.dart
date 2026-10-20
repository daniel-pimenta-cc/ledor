import 'package:flutter/services.dart';

const _channel = MethodChannel('ledor/screen');

/// Holds the display awake while [on]. Only Android implements the channel
/// (FLAG_KEEP_SCREEN_ON in MainActivity); elsewhere this is a no-op.
Future<void> setKeepScreenOn(bool on) async {
  try {
    await _channel.invokeMethod<void>('keepOn', on);
  } on MissingPluginException {
    // ponytail: iOS/Linux keep the OS idle timeout; add a handler there if
    // dimming mid-RSVP shows up on those platforms.
  }
}
