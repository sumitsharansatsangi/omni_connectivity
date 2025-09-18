// This file is only a convenience re-export. The actual implementation
// will be selected by conditional imports in api.dart (see above).
export 'impl_io.dart' if (dart.library.html) 'impl_web.dart';
