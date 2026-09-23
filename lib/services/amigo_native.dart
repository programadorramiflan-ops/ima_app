import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef AmigoInitC = Int32 Function();
typedef AmigoInitDart = int Function();

class AmigoNativeService {
  static DynamicLibrary? _lib;

  static void init() {
    if (_lib != null) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libamigo_core.so');
    } else {
      _lib = DynamicLibrary.process();
    }
  }

  static int inicializarAmigoCore() {
    init();
    final AmigoInitDart amigoInit = _lib!
        .lookup<NativeFunction<AmigoInitC>>('amigo_init')
        .asFunction();
    return amigoInit();
  }
}
