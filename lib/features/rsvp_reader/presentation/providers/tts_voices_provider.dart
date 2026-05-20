import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/tts_backend.dart';
import 'tts_backend_provider.dart';

/// Loads the list of voices the platform backend reports. Cached for the
/// lifetime of the provider; the picker UI can re-fetch by invalidating
/// this provider after a "refresh" button (none today, but the seam is
/// here).
///
/// May complete with an empty list when the engine has no voices
/// installed (rare on Android, common on a stripped-down Linux), and may
/// complete with an error when the backend's `init()` fails (e.g.
/// `spd-say` not on PATH). UI handles both via AsyncValue.when.
final ttsVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  final backend = ref.watch(ttsBackendProvider);
  await backend.init();
  final voices = await backend.getVoices();
  // Stable ordering: locale first (so the picker can group), then name.
  voices.sort((a, b) {
    final byLocale = a.locale.compareTo(b.locale);
    if (byLocale != 0) return byLocale;
    return a.name.compareTo(b.name);
  });
  return voices;
});
