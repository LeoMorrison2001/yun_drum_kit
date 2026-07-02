import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class DrumAudioEngine {
  DrumAudioEngine._();

  static final DrumAudioEngine instance = DrumAudioEngine._();

  final SoLoud _engine = SoLoud.instance;
  final Map<String, AudioSource> _sounds = {};
  Future<void>? _initializing;

  bool get isReady => _sounds.isNotEmpty;

  Future<void> initialize(Iterable<String> assetPaths) {
    return _initializing ??= _initialize(assetPaths);
  }

  Future<void> _initialize(Iterable<String> assetPaths) async {
    try {
      if (!_engine.isInitialized) {
        await _engine.init(
          sampleRate: 48000,
          bufferSize: 512,
          channels: Channels.stereo,
          lowLatency: true,
        );
        _engine.setMaxActiveVoiceCount(32);
      }

      final paths = assetPaths.toSet();
      await Future.wait(paths.map(_loadSound));
    } catch (error, stackTrace) {
      debugPrint('虚拟鼓音频初始化失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      _initializing = null;
    }
  }

  Future<void> _loadSound(String assetPath) async {
    if (_sounds.containsKey(assetPath)) return;

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = Uint8List.sublistView(
        data.buffer.asUint8List(),
        data.offsetInBytes,
        data.offsetInBytes + data.lengthInBytes,
      );
      _sounds[assetPath] = await _engine.loadMem(
        assetPath,
        bytes,
        mode: LoadMode.memory,
      );
    } catch (error) {
      debugPrint('无法加载鼓声音频 $assetPath：$error');
    }
  }

  void play(String assetPath) {
    final sound = _sounds[assetPath];
    if (sound == null || !_engine.isInitialized) return;

    _engine.play(sound);
  }
}
