import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/linux_file_dialog.dart';

void main() {
  group('hasLinuxFileDialogTool', () {
    test('is false when none of the tools is installed', () async {
      expect(await hasLinuxFileDialogTool(isOnPath: (_) async => false), isFalse);
    });

    test('is true when only zenity is installed', () async {
      expect(
        await hasLinuxFileDialogTool(isOnPath: (t) async => t == 'zenity'),
        isTrue,
      );
    });

    test('is true when only kdialog is installed', () async {
      expect(
        await hasLinuxFileDialogTool(isOnPath: (t) async => t == 'kdialog'),
        isTrue,
      );
    });

    test('checks every tool file_picker supports', () async {
      final asked = <String>[];
      await hasLinuxFileDialogTool(isOnPath: (t) async {
        asked.add(t);
        return false;
      });
      expect(asked, linuxFileDialogTools);
    });
  });
}
