import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Routes every path_provider call to a tearDown-cleaned temp dir so flows
/// that persist files (EPUB copies, inline images) never touch the real
/// platform directories.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.docs);
  final Directory docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs.path;

  @override
  Future<String?> getTemporaryPath() async => docs.path;
}
