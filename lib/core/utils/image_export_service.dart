import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a widget wrapped in a [RepaintBoundary] to a PNG and hands it
/// to the OS share sheet.
///
/// [pixelRatio] controls export resolution. `3.0` on a 360dp-wide card
/// yields ~1080px, matching Instagram/Stories-quality output.
Future<void> shareWidgetAsPng({
  required GlobalKey boundaryKey,
  required String filename,
  String? shareText,
  double pixelRatio = 3.0,
}) async {
  final bytes = await _capturePng(boundaryKey, pixelRatio: pixelRatio);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename.png');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: shareText,
    ),
  );
}

Future<Uint8List> _capturePng(
  GlobalKey key, {
  required double pixelRatio,
}) async {
  // Ensure the boundary has painted at least once before capturing —
  // without this, first export after hot-route can return a blank or
  // partially-painted PNG.
  await SchedulerBinding.instance.endOfFrame;
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to encode widget to PNG');
  }
  return byteData.buffer.asUint8List();
}
