import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Power-user generation options (Phase 8). Hidden behind the collapsed
/// "Advanced" panel in Settings — off by default, never required.
///
/// - [temperature] applies to every generation immediately.
/// - [contextSize] takes effect the next time a model loads (it sizes the
///   KV cache at load, so it cannot change mid-session).
class GenerationSettings {
  const GenerationSettings({
    this.temperature = defaultTemperature,
    this.contextSize = defaultContextSize,
  });

  static const double defaultTemperature = 0.8;
  static const int defaultContextSize = 2048;

  static const double minTemperature = 0.0;
  static const double maxTemperature = 1.5;

  static const List<int> contextOptions = [1024, 2048, 4096];

  final double temperature;
  final int contextSize;

  bool get isDefault =>
      temperature == defaultTemperature && contextSize == defaultContextSize;

  GenerationSettings copyWith({double? temperature, int? contextSize}) {
    return GenerationSettings(
      temperature: temperature ?? this.temperature,
      contextSize: contextSize ?? this.contextSize,
    );
  }
}

class GenerationSettingsController extends Notifier<GenerationSettings> {
  static const String _temperaturePrefKey = 'generation_temperature';
  static const String _contextSizePrefKey = 'generation_context_size';

  @override
  GenerationSettings build() {
    _loadSaved();
    return const GenerationSettings();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final temperature = prefs.getDouble(_temperaturePrefKey);
    final contextSize = prefs.getInt(_contextSizePrefKey);
    state = GenerationSettings(
      temperature: _clampTemperature(temperature) ??
          GenerationSettings.defaultTemperature,
      contextSize:
          _validContextSize(contextSize) ?? GenerationSettings.defaultContextSize,
    );
  }

  Future<void> setTemperature(double value) async {
    final clamped = _clampTemperature(value) ?? state.temperature;
    if (clamped == state.temperature) return;
    state = state.copyWith(temperature: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_temperaturePrefKey, clamped);
  }

  Future<void> setContextSize(int value) async {
    if (!GenerationSettings.contextOptions.contains(value)) return;
    if (value == state.contextSize) return;
    state = state.copyWith(contextSize: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_contextSizePrefKey, value);
  }

  Future<void> resetDefaults() async {
    state = const GenerationSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_temperaturePrefKey);
    await prefs.remove(_contextSizePrefKey);
  }

  static double? _clampTemperature(double? value) {
    if (value == null || value.isNaN) return null;
    return value.clamp(
      GenerationSettings.minTemperature,
      GenerationSettings.maxTemperature,
    );
  }

  static int? _validContextSize(int? value) {
    if (value == null) return null;
    return GenerationSettings.contextOptions.contains(value) ? value : null;
  }
}

final generationSettingsProvider =
    NotifierProvider<GenerationSettingsController, GenerationSettings>(
  GenerationSettingsController.new,
);
