import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // Required in pubspec.yaml
import 'package:flutter/foundation.dart';

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
    try {
      _lib = Platform.isIOS ? DynamicLibrary.process() : DynamicLibrary.executable();
      _dsp = _lib.lookupFunction<DspCreateC, DspCreateDart>('dsp_create')();
      if (_dsp == nullptr) {
        throw StateError('AudioEngine: dsp_create returned a null pointer');
      }
      _loadEq = _lib.lookupFunction<DspLoadEqC, DspLoadEqDart>('dsp_load_eq');
      _process = _lib.lookupFunction<DspProcessC, DspProcessDart>('dsp_process');
    } catch (e) {
      debugPrint('AudioEngine: initialization failed: $e');
      rethrow;
    }
  }

  void loadEqContent(String content, double sampleRate) {
    Pointer<Utf8>? ptr;
    try {
      ptr = content.toNativeUtf8();
      _loadEq(_dsp, ptr, sampleRate);
    } catch (e) {
      debugPrint('AudioEngine: loadEqContent error: $e');
    } finally {
      if (ptr != null) calloc.free(ptr);
    }
  }

  void processBuffer(Pointer<Float> buffer, int length) {
    _process(_dsp, buffer, length);
  }

  void dispose() {
    try {
      _lib.lookupFunction<DspDestroyC, DspDestroyDart>('dsp_destroy')(_dsp);
    } catch (e) {
      debugPrint('AudioEngine: dispose error: $e');
    }
  }
}