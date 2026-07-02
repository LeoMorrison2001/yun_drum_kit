import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:yun_drum_kit/audio/drum_audio_engine.dart';

class RhythmLoopSpec {
  const RhythmLoopSpec({
    required this.measures,
    required this.assetPaths,
    required this.bpm,
    required this.stepCount,
    required this.subdivisionsPerBeat,
  });

  final List<List<List<bool>>> measures;
  final List<String> assetPaths;
  final int bpm;
  final int stepCount;
  final int subdivisionsPerBeat;
}

class RhythmPlaybackCursor {
  const RhythmPlaybackCursor({
    required this.measureIndex,
    required this.stepIndex,
  });

  final int measureIndex;
  final int stepIndex;
}

class RenderedRhythmLoop {
  const RenderedRhythmLoop({
    required this.wavBytes,
    required this.duration,
    required this.stepDuration,
  });

  final Uint8List wavBytes;
  final Duration duration;
  final Duration stepDuration;
}

Future<RenderedRhythmLoop> renderRhythmLoop(RhythmLoopSpec spec) async {
  final assetBytes = <String, Uint8List>{};
  for (var instrument = 0; instrument < spec.assetPaths.length; instrument++) {
    final isUsed = spec.measures.any(
      (measure) =>
          instrument < measure.length &&
          measure[instrument].any((enabled) => enabled),
    );
    if (!isUsed) continue;

    final data = await rootBundle.load(spec.assetPaths[instrument]);
    assetBytes[spec.assetPaths[instrument]] = Uint8List.sublistView(
      data.buffer.asUint8List(),
      data.offsetInBytes,
      data.offsetInBytes + data.lengthInBytes,
    );
  }

  return compute(
    _renderLoop,
    _RenderRequest(
      measures: spec.measures
          .map(
            (measure) =>
                measure.map((steps) => List<bool>.from(steps)).toList(),
          )
          .toList(),
      assetPaths: List<String>.from(spec.assetPaths),
      assetBytes: assetBytes,
      bpm: spec.bpm,
      stepCount: spec.stepCount,
      subdivisionsPerBeat: spec.subdivisionsPerBeat,
    ),
  );
}

class SampleAccurateRhythmPlayer {
  SoLoud? _engine;

  AudioSource? _loopSource;
  SoundHandle? _loopHandle;
  Duration _loopDuration = Duration.zero;
  Duration _stepDuration = Duration.zero;
  int _stepCount = 0;
  int _measureCount = 0;
  int _generation = 0;

  bool get isPlaying =>
      _engine != null &&
      _loopHandle != null &&
      _engine!.isInitialized &&
      _engine!.getIsValidVoiceHandle(_loopHandle!);

  RhythmPlaybackCursor? get cursor {
    final handle = _loopHandle;
    final engine = _engine;
    if (handle == null ||
        engine == null ||
        !engine.isInitialized ||
        !engine.getIsValidVoiceHandle(handle) ||
        _stepDuration == Duration.zero ||
        _stepCount == 0 ||
        _measureCount == 0) {
      return null;
    }

    final positionMicros =
        engine.getPosition(handle).inMicroseconds %
        _loopDuration.inMicroseconds;
    final absoluteStep = positionMicros ~/ _stepDuration.inMicroseconds;
    return RhythmPlaybackCursor(
      measureIndex: (absoluteStep ~/ _stepCount) % _measureCount,
      stepIndex: absoluteStep % _stepCount,
    );
  }

  Future<bool> start(RhythmLoopSpec spec) async {
    final generation = ++_generation;
    await stop(invalidatePendingStart: false);

    await DrumAudioEngine.instance.initialize(spec.assetPaths);
    if (!DrumAudioEngine.instance.isReady || generation != _generation) {
      return false;
    }
    final engine = _engine ??= SoLoud.instance;
    if (!engine.isInitialized) return false;

    final rendered = await renderRhythmLoop(spec);
    if (generation != _generation || !engine.isInitialized) return false;

    final source = await engine.loadMem(
      'rhythm_loop_${DateTime.now().microsecondsSinceEpoch}.wav',
      rendered.wavBytes,
      mode: LoadMode.memory,
    );
    if (generation != _generation) {
      await engine.disposeSource(source);
      return false;
    }

    _loopSource = source;
    _loopDuration = rendered.duration;
    _stepDuration = rendered.stepDuration;
    _stepCount = spec.stepCount;
    _measureCount = spec.measures.length;
    _loopHandle = engine.play(source, looping: true);
    return true;
  }

  Future<void> stop({bool invalidatePendingStart = true}) async {
    if (invalidatePendingStart) _generation++;
    final handle = _loopHandle;
    final source = _loopSource;
    final engine = _engine;
    _loopHandle = null;
    _loopSource = null;

    if (engine != null && engine.isInitialized && handle != null) {
      await engine.stop(handle);
    }
    if (engine != null && engine.isInitialized && source != null) {
      await engine.disposeSource(source);
    }
  }

  Future<void> dispose() => stop();
}

class _RenderRequest {
  const _RenderRequest({
    required this.measures,
    required this.assetPaths,
    required this.assetBytes,
    required this.bpm,
    required this.stepCount,
    required this.subdivisionsPerBeat,
  });

  final List<List<List<bool>>> measures;
  final List<String> assetPaths;
  final Map<String, Uint8List> assetBytes;
  final int bpm;
  final int stepCount;
  final int subdivisionsPerBeat;
}

class _DecodedPcm {
  const _DecodedPcm({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final Float32List samples;

  int get frameCount => samples.length ~/ channels;
}

RenderedRhythmLoop _renderLoop(_RenderRequest request) {
  const outputSampleRate = 44100;
  const outputChannels = 2;
  final samplesPerStep =
      outputSampleRate * 60 / request.bpm / request.subdivisionsPerBeat;
  final totalSteps = request.measures.length * request.stepCount;
  final loopFrames = math.max(1, (totalSteps * samplesPerStep).round());
  final mix = Float32List(loopFrames * outputChannels);

  final decoded = <String, _DecodedPcm>{};
  for (final entry in request.assetBytes.entries) {
    decoded[entry.key] = _decodeWav(entry.value);
  }

  for (
    var measureIndex = 0;
    measureIndex < request.measures.length;
    measureIndex++
  ) {
    final measure = request.measures[measureIndex];
    for (
      var instrument = 0;
      instrument < request.assetPaths.length;
      instrument++
    ) {
      final sample = decoded[request.assetPaths[instrument]];
      if (sample == null || instrument >= measure.length) continue;
      final steps = measure[instrument];

      for (
        var stepIndex = 0;
        stepIndex < request.stepCount && stepIndex < steps.length;
        stepIndex++
      ) {
        if (!steps[stepIndex]) continue;
        final absoluteStep = measureIndex * request.stepCount + stepIndex;
        final startFrame = (absoluteStep * samplesPerStep).round();
        _mixSample(
          mix: mix,
          loopFrames: loopFrames,
          outputSampleRate: outputSampleRate,
          startFrame: startFrame,
          sample: sample,
        );
      }
    }
  }

  var peak = 0.0;
  for (final value in mix) {
    peak = math.max(peak, value.abs());
  }
  final gain = peak > 0.96 ? 0.96 / peak : 1.0;
  final wavBytes = _encodePcm16Wav(
    mix,
    sampleRate: outputSampleRate,
    channels: outputChannels,
    gain: gain,
  );

  return RenderedRhythmLoop(
    wavBytes: wavBytes,
    duration: Duration(
      microseconds: (loopFrames * 1000000 / outputSampleRate).round(),
    ),
    stepDuration: Duration(
      microseconds: (samplesPerStep * 1000000 / outputSampleRate).round(),
    ),
  );
}

void _mixSample({
  required Float32List mix,
  required int loopFrames,
  required int outputSampleRate,
  required int startFrame,
  required _DecodedPcm sample,
}) {
  final rateRatio = sample.sampleRate / outputSampleRate;
  final outputFrameCount = (sample.frameCount / rateRatio).ceil();

  for (var outputFrame = 0; outputFrame < outputFrameCount; outputFrame++) {
    final sourceFrame = math.min(
      sample.frameCount - 1,
      (outputFrame * rateRatio).floor(),
    );
    final targetFrame = (startFrame + outputFrame) % loopFrames;
    final targetOffset = targetFrame * 2;
    final sourceOffset = sourceFrame * sample.channels;
    final left = sample.samples[sourceOffset];
    final right = sample.channels == 1
        ? left
        : sample.samples[sourceOffset + 1];
    mix[targetOffset] += left;
    mix[targetOffset + 1] += right;
  }
}

_DecodedPcm _decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 44 ||
      _ascii(bytes, 0, 4) != 'RIFF' ||
      _ascii(bytes, 8, 4) != 'WAVE') {
    throw const FormatException('Unsupported WAV file');
  }

  var offset = 12;
  var format = 0;
  var channels = 0;
  var sampleRate = 0;
  var bitsPerSample = 0;
  var dataOffset = 0;
  var dataLength = 0;

  while (offset + 8 <= bytes.length) {
    final chunkId = _ascii(bytes, offset, 4);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkData = offset + 8;
    if (chunkData + chunkSize > bytes.length) break;

    if (chunkId == 'fmt ') {
      format = data.getUint16(chunkData, Endian.little);
      channels = data.getUint16(chunkData + 2, Endian.little);
      sampleRate = data.getUint32(chunkData + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkData + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkData;
      dataLength = chunkSize;
    }
    offset = chunkData + chunkSize + chunkSize.isOdd.toInt();
  }

  if (channels < 1 ||
      sampleRate < 1 ||
      dataOffset == 0 ||
      !{1, 3, 65534}.contains(format)) {
    throw const FormatException('Unsupported WAV encoding');
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  if (![2, 3, 4].contains(bytesPerSample)) {
    throw FormatException('Unsupported WAV bit depth: $bitsPerSample');
  }
  final sampleCount = dataLength ~/ bytesPerSample;
  final samples = Float32List(sampleCount);

  for (var index = 0; index < sampleCount; index++) {
    final sampleOffset = dataOffset + index * bytesPerSample;
    samples[index] = switch ((format, bitsPerSample)) {
      (3, 32) => data.getFloat32(sampleOffset, Endian.little),
      (_, 16) => data.getInt16(sampleOffset, Endian.little) / 32768.0,
      (_, 24) => _readPcm24(bytes, sampleOffset) / 8388608.0,
      (_, 32) => data.getInt32(sampleOffset, Endian.little) / 2147483648.0,
      _ => throw FormatException(
        'Unsupported WAV format: $format/$bitsPerSample',
      ),
    };
  }

  return _DecodedPcm(
    sampleRate: sampleRate,
    channels: channels,
    samples: samples,
  );
}

int _readPcm24(Uint8List bytes, int offset) {
  var value =
      bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  if ((value & 0x800000) != 0) value -= 0x1000000;
  return value;
}

Uint8List _encodePcm16Wav(
  Float32List samples, {
  required int sampleRate,
  required int channels,
  required double gain,
}) {
  const headerSize = 44;
  final pcmLength = samples.length * 2;
  final bytes = Uint8List(headerSize + pcmLength);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, pcmLength, Endian.little);

  for (var index = 0; index < samples.length; index++) {
    final value = (samples[index] * gain).clamp(-1.0, 1.0);
    data.setInt16(
      headerSize + index * 2,
      (value * 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  bytes.setRange(offset, offset + value.length, value.codeUnits);
}

extension on bool {
  int toInt() => this ? 1 : 0;
}
