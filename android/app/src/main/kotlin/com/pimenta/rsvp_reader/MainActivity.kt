package com.pimenta.rsvp_reader

import com.ryanheise.audioservice.AudioServiceActivity

/// Extending AudioServiceActivity (instead of FlutterActivity) lets the
/// audio_service plugin observe `MEDIA_BUTTON` intents — headphone /
/// bluetooth play-pause buttons reach the Flutter handler this way. It's
/// also what unlocks pre-activity intent handling for the media session.
class MainActivity : AudioServiceActivity()
