import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Generador puro en Dart de tonos WAV PCM 16 bits para alertas sin depender de red ni archivos binarios externos.
abstract final class TaxiyaSoundGenerator {
  static const int _sampleRate = 22050;

  /// Timbre breve de dos notas para confirmaciones (viaje aceptado, taxi en puerta, mensaje).
  static Uint8List buildChimeWav() {
    return _synthesizeSequence(const <_ToneStep>[
      _ToneStep(freqHz: 880, durationMs: 130, amplitude: 0.45),
      _ToneStep(freqHz: 0, durationMs: 35, amplitude: 0),
      _ToneStep(freqHz: 1174.66, durationMs: 210, amplitude: 0.5),
    ]);
  }

  /// Llamado persistente de pedido entrante para choferes.
  static Uint8List buildTripRequestRingWav() {
    return _synthesizeSequence(const <_ToneStep>[
      _ToneStep(freqHz: 740, durationMs: 160, amplitude: 0.6),
      _ToneStep(freqHz: 987.77, durationMs: 220, amplitude: 0.65),
      _ToneStep(freqHz: 0, durationMs: 140, amplitude: 0),
      _ToneStep(freqHz: 740, durationMs: 160, amplitude: 0.6),
      _ToneStep(freqHz: 987.77, durationMs: 260, amplitude: 0.65),
    ]);
  }

  /// Alerta preventiva descendente (por ejemplo a los 3 minutos sin acercarse al origen).
  static Uint8List buildWarningWav() {
    return _synthesizeSequence(const <_ToneStep>[
      _ToneStep(freqHz: 660, durationMs: 180, amplitude: 0.55),
      _ToneStep(freqHz: 0, durationMs: 70, amplitude: 0),
      _ToneStep(freqHz: 493.88, durationMs: 260, amplitude: 0.55),
    ]);
  }

  static Uint8List _synthesizeSequence(List<_ToneStep> steps) {
    final samples = <int>[];
    for (final step in steps) {
      final count = (_sampleRate * step.durationMs) ~/ 1000;
      if (step.freqHz <= 0 || step.amplitude <= 0) {
        samples.addAll(List<int>.filled(count, 0));
        continue;
      }
      final fadeSamples = math.max(1, math.min(count ~/ 5, 220));
      for (var i = 0; i < count; i++) {
        var env = 1.0;
        if (i < fadeSamples) {
          env = i / fadeSamples;
        } else if (i > count - fadeSamples) {
          env = (count - i) / fadeSamples;
        }
        final t = i / _sampleRate;
        final wave = math.sin(2 * math.pi * step.freqHz * t);
        final pcm = (wave * env * step.amplitude * 32767).round().clamp(
          -32768,
          32767,
        );
        samples.add(pcm);
      }
    }

    final dataBytes = samples.length * 2;
    final byteData = ByteData(44 + dataBytes);

    // Cabecera RIFF/WAVE
    _writeAscii(byteData, 0, 'RIFF');
    byteData.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(byteData, 8, 'WAVE');

    // Bloque fmt
    _writeAscii(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, _sampleRate, Endian.little);
    byteData.setUint32(28, _sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    // Bloque data
    _writeAscii(byteData, 36, 'data');
    byteData.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      byteData.setInt16(44 + (i * 2), samples[i], Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  static void _writeAscii(ByteData data, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}

class _ToneStep {
  const _ToneStep({
    required this.freqHz,
    required this.durationMs,
    required this.amplitude,
  });

  final double freqHz;
  final int durationMs;
  final double amplitude;
}

/// Reproductor simple de alertas sonoras locales para choferes y pasajeros.
class TaxiyaSoundService {
  TaxiyaSoundService();

  AudioPlayer? _oneShotPlayer;
  AudioPlayer? _loopPlayer;

  static final Uint8List _chimeBytes = TaxiyaSoundGenerator.buildChimeWav();
  static final Uint8List _ringBytes =
      TaxiyaSoundGenerator.buildTripRequestRingWav();
  static final Uint8List _warningBytes = TaxiyaSoundGenerator.buildWarningWav();

  Future<void> playChime() async {
    await _playOneShot(_chimeBytes);
  }

  Future<void> playWarning() async {
    await _playOneShot(_warningBytes);
  }

  Future<void> startOrderRing() async {
    try {
      _loopPlayer ??= AudioPlayer();
      await _loopPlayer!.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer!.play(BytesSource(_ringBytes), volume: 1.0);
    } catch (_) {
      // En emuladores sin salida de audio o pruebas unitarias continuamos sin bloquear.
    }
  }

  Future<void> stopOrderRing() async {
    try {
      await _loopPlayer?.stop();
    } catch (_) {}
  }

  Future<void> _playOneShot(Uint8List bytes) async {
    try {
      _oneShotPlayer ??= AudioPlayer();
      await _oneShotPlayer!.setReleaseMode(ReleaseMode.stop);
      await _oneShotPlayer!.play(BytesSource(bytes), volume: 1.0);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _oneShotPlayer?.dispose();
    } catch (_) {}
    try {
      await _loopPlayer?.dispose();
    } catch (_) {}
  }
}
