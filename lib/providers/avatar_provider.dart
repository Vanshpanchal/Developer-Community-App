import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../models/avatar_config.dart';
import '../services/avatar_service.dart';
import '../services/secrets_service.dart';

/// ChangeNotifier Provider for avatar state.
/// On save: persists config locally (GetStorage) AND updates
/// profilePicture in Firestore via SecretsService.
class AvatarProvider extends ChangeNotifier {
  static const String _storageKey = 'avatar_config';

  final GetStorage _storage = GetStorage();
  final AvatarService _service = AvatarService.instance;

  late AvatarConfig _config;
  AvatarGender _gender = AvatarGender.all;

  AvatarConfig get config => _config;
  AvatarGender get gender => _gender;

  AvatarProvider() {
    _config = _loadSavedConfig();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  AvatarConfig _loadSavedConfig() {
    final raw = _storage.read<String>(_storageKey);
    if (raw == null || raw.isEmpty) return AvatarConfig.defaults();
    try {
      return AvatarConfig.fromJsonString(raw);
    } catch (_) {
      return AvatarConfig.defaults();
    }
  }

  /// Persists config locally AND updates profilePicture + profileDominantColor
  /// in Firestore (single write).
  /// Returns the final avatar URL so callers can refresh their UI.
  Future<String> saveAvatar() async {
    // 1. Local storage
    await _storage.write(_storageKey, _config.toJsonString());

    // 2. Firebase — write profilePicture and derive dominantColor from bg hex
    final url = _config.avatarUrl;
    await SecretsService.instance.saveAvatarUrl(
      url,
      bgHex: _config.backgroundColor,
    );

    notifyListeners();
    return url;
  }

  // ---------------------------------------------------------------------------
  // Gender filter
  // ---------------------------------------------------------------------------

  void setGender(AvatarGender gender) {
    _gender = gender;
    notifyListeners();
  }

  /// Filtered predefined configs based on current gender selection.
  List<AvatarConfig> get filteredConfigs =>
      _service.predefinedConfigsFor(_gender);

  // ---------------------------------------------------------------------------
  // Mutation helpers
  // ---------------------------------------------------------------------------

  void updateSeed(String seed) {
    _config = _config.copyWith(seed: seed);
    notifyListeners();
  }

  void updateHair(String? hair) {
    _config = _config.copyWith(hair: hair, clearHair: hair == null);
    notifyListeners();
  }

  void updateEyes(String? eyes) {
    _config = _config.copyWith(eyes: eyes, clearEyes: eyes == null);
    notifyListeners();
  }

  void updateMouth(String? mouth) {
    _config = _config.copyWith(mouth: mouth, clearMouth: mouth == null);
    notifyListeners();
  }

  void updateAccessories(String? accessories) {
    _config = _config.copyWith(
        accessories: accessories, clearAccessories: accessories == null);
    notifyListeners();
  }

  void updateBackground(String? backgroundColor) {
    _config = _config.copyWith(backgroundColor: backgroundColor);
    notifyListeners();
  }

  void changeStyle(String style) {
    _config = AvatarConfig(
      seed: _config.seed,
      style: style,
      backgroundColor: _config.backgroundColor,
    );
    notifyListeners();
  }

  void selectPredefined(AvatarConfig selected) {
    _config = selected;
    notifyListeners();
  }

  void randomizeAvatar() {
    _config = _service.randomConfig(
      style: _config.style,
      backgroundColor: _config.backgroundColor ?? 'b6e3f4',
    );
    notifyListeners();
  }

  void resetAvatar() {
    _config = AvatarConfig.defaults();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  String get avatarUrl => _config.avatarUrl;

  bool supportsCustomization(String category) =>
      _service.styleSupports(_config.style, category);

  List<String> optionsFor(String category) =>
      _service.getOptionsForStyle(category, _config.style);
}
