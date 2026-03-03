// Единая точка доступа к платформенно-зависимому коду (dart:io).
// На web — stub, на mobile/desktop — реализация с файловой системой.
export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
