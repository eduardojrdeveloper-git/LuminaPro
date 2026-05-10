import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // Required in pubspec.yaml

typedef DspCreateC = Pointer<Void> Function();
typedef DspCreateDart = Pointer<Void> Function();

typedef DspDestroyC = Void Function(Pointer<Void> dsp);
typedef DspDestroyDart = void Function(Pointer<Void> dsp);

typedef DspLoadEqC = Void Function(Pointer<Void> dsp, Pointer<Utf8> eq_content, Double fs);
typedef DspLoadEqDart = void Function(Pointer<Void> dsp, Pointer<Utf8> eq_content, double fs);

typedef DspProcessC = Void Function(Pointer<Void> dsp, Pointer<Float> buffer, Int32 length);
typedef DspProcessDart = void Function(Pointer<Void> dsp, Pointer<Float> buffer, int length);

class AudioEngine {
  late DynamicLibrary _lib;
  late Pointer<Void> _dsp;
  late DspLoadEqDart _loadEq;
  late DspProcessDart _process;

  AudioEngine() {
    _lib = Platform.isIOS ? DynamicLibrary.process() : DynamicLibrary.executable();
    _dsp = _lib.lookupFunction<DspCreateC, DspCreateDart>('dsp_create')();
    _loadEq = _lib.lookupFunction<DspLoadEqC, DspLoadEqDart>('dsp_load_eq');
    _process = _lib.lookupFunction<DspProcessC, DspProcessDart>('dsp_process');
  }

  void loadEqContent(String content, double sampleRate) {
    final ptr = content.toNativeUtf8();
    _loadEq(_dsp, ptr, sampleRate);
    calloc.free(ptr);
  }

  void processBuffer(Pointer<Float> buffer, int length) {
    _process(_dsp, buffer, length);
  }

  void dispose() {
    _lib.lookupFunction<DspDestroyC, DspDestroyDart>('dsp_destroy')(_dsp);
  }
}