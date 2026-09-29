import 'dart:io';

/// CLI tools `file_picker` shells out to for its native dialog on Linux, in the
/// order it tries them.
const linuxFileDialogTools = ['qarma', 'kdialog', 'zenity'];

Future<bool> _isOnPath(String tool) async {
  try {
    final result = await Process.run('which', [tool]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Whether at least one of [linuxFileDialogTools] is installed. Without one,
/// `file_picker` throws a generic exception, so the UI checks up front to show
/// an actionable message instead.
Future<bool> hasLinuxFileDialogTool({
  Future<bool> Function(String tool) isOnPath = _isOnPath,
}) async {
  for (final tool in linuxFileDialogTools) {
    if (await isOnPath(tool)) return true;
  }
  return false;
}
