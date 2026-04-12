import 'dart:math';
import '../models/avatar_config.dart';

/// Gender filter enum for the predefined avatar picker.
enum AvatarGender { all, male, female }

/// Provides DiceBear avatar generation utilities.
class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  // ---------------------------------------------------------------------------
  // Supported styles
  // ---------------------------------------------------------------------------

  static const List<Map<String, String>> supportedStyles = [
    {'id': 'adventurer',          'label': 'Adventurer',         'emoji': '🧙'},
    {'id': 'adventurer-neutral',  'label': 'Adventurer Neutral', 'emoji': '🧝'},
    {'id': 'avataaars',           'label': 'Avataaars',          'emoji': '😎'},
    {'id': 'bottts',              'label': 'Bot',                'emoji': '🤖'},
    {'id': 'pixel-art',           'label': 'Pixel Art',          'emoji': '👾'},
    {'id': 'fun-emoji',           'label': 'Fun Emoji',          'emoji': '😄'},
    {'id': 'lorelei',             'label': 'Lorelei',            'emoji': '🌟'},
    {'id': 'notionists',          'label': 'Notionists',         'emoji': '📝'},
  ];

  // ---------------------------------------------------------------------------
  // Predefined avatar templates — all Notionists style
  // gender: 'neutral' — shown under All / Male / Female filters
  // ---------------------------------------------------------------------------

  static const List<Map<String, String>> predefinedEntries = [
    {'seed': 'Atlas',    'style': 'notionists', 'bg': 'd1d4f9', 'gender': 'neutral'},
    {'seed': 'Echo',     'style': 'notionists', 'bg': 'ffd5dc', 'gender': 'neutral'},
    {'seed': 'Zephyr',   'style': 'notionists', 'bg': 'b6e3f4', 'gender': 'neutral'},
    {'seed': 'Storm',    'style': 'notionists', 'bg': 'c0aede', 'gender': 'neutral'},
    {'seed': 'Phoenix',  'style': 'notionists', 'bg': 'fce4ec', 'gender': 'neutral'},
    {'seed': 'Sol',      'style': 'notionists', 'bg': 'c1e1c5', 'gender': 'neutral'},
    {'seed': 'Lyra',     'style': 'notionists', 'bg': 'ede7f6', 'gender': 'neutral'},
    {'seed': 'Nova',     'style': 'notionists', 'bg': 'fff3e0', 'gender': 'neutral'},
    {'seed': 'Coda',     'style': 'notionists', 'bg': 'e0f2fe', 'gender': 'neutral'},
    {'seed': 'Orion',    'style': 'notionists', 'bg': 'ffefd5', 'gender': 'neutral'},
    {'seed': 'Sage',     'style': 'notionists', 'bg': 'b2dfdb', 'gender': 'neutral'},
    {'seed': 'Rowan',    'style': 'notionists', 'bg': 'fdf6e3', 'gender': 'neutral'},
    {'seed': 'River',    'style': 'notionists', 'bg': 'e8eaf6', 'gender': 'neutral'},
    {'seed': 'Quinn',    'style': 'notionists', 'bg': 'f0fdf4', 'gender': 'neutral'},
    {'seed': 'Blake',    'style': 'notionists', 'bg': 'ffdfbf', 'gender': 'neutral'},
    {'seed': 'Eden',     'style': 'notionists', 'bg': 'ffd5dc', 'gender': 'neutral'},
    {'seed': 'Kai',      'style': 'notionists', 'bg': 'c1e1c5', 'gender': 'neutral'},
    {'seed': 'Luna',     'style': 'notionists', 'bg': 'd1d4f9', 'gender': 'neutral'},
    {'seed': 'Felix',    'style': 'notionists', 'bg': 'b6e3f4', 'gender': 'neutral'},
    {'seed': 'Willow',   'style': 'notionists', 'bg': 'fce4ec', 'gender': 'neutral'},
  ];

  // ---------------------------------------------------------------------------
  // Per-style option catalogues
  // ---------------------------------------------------------------------------

  static const Map<String, List<String>> hairOptions = {
    'adventurer': [
      'long01', 'long02', 'long03', 'long04', 'long05',
      'short01', 'short02', 'short03', 'short04', 'short05',
    ],
    'adventurer-neutral': [
      'long01', 'long02', 'short01', 'short02', 'short03',
    ],
    'avataaars': [
      'longHairBigHair', 'longHairBob', 'longHairCurly', 'longHairDreads',
      'longHairFrida', 'longHairFro', 'longHairMiaWallace', 'longHairStraight',
      'shortHairDreads01', 'shortHairDreads02', 'shortHairFrizzle',
      'shortHairShaggyMullet', 'shortHairShortCurly', 'shortHairShortFlat',
      'shortHairShortRound', 'shortHairShortWaved', 'shortHairSides',
    ],
    'lorelei': ['long01', 'long02', 'long03', 'short01', 'short02'],
  };

  static const Map<String, List<String>> eyeOptions = {
    'adventurer': [
      'variant01', 'variant02', 'variant03', 'variant04', 'variant05',
      'variant06', 'variant07', 'variant08', 'variant09', 'variant10',
    ],
    'adventurer-neutral': ['variant01', 'variant02', 'variant03', 'variant04'],
    'avataaars': [
      'close', 'cry', 'default', 'dizzy', 'eyeRoll', 'happy',
      'hearts', 'side', 'squint', 'surprised', 'wink', 'winkWacky',
    ],
    'bottts': [
      'bulging', 'dizzy', 'eva', 'glow', 'happy', 'hearts',
      'robocop', 'round', 'roundFrame01', 'roundFrame02', 'sensor', 'shade01',
    ],
    'fun-emoji': [
      'closed', 'closed2', 'crying', 'cute', 'glasses', 'love',
      'pissed', 'plain', 'sad', 'shades', 'sleepClose', 'stars', 'tearDrop',
    ],
    'lorelei': ['variant01', 'variant02', 'variant03', 'variant04', 'variant05'],
    'pixel-art': [
      'variant01', 'variant02', 'variant03', 'variant04', 'variant05',
      'variant06', 'variant07', 'variant08', 'variant09',
    ],
  };

  static const Map<String, List<String>> mouthOptions = {
    'adventurer': [
      'variant01', 'variant02', 'variant03', 'variant04', 'variant05',
      'variant06', 'variant07', 'variant08', 'variant09', 'variant10',
    ],
    'adventurer-neutral': [
      'variant01', 'variant02', 'variant03', 'variant04', 'variant05',
    ],
    'avataaars': [
      'concerned', 'default', 'disbelief', 'eating', 'grimace',
      'sad', 'screamOpen', 'serious', 'smile', 'tongue', 'twinkle', 'vomit',
    ],
    'fun-emoji': [
      'cute', 'drip', 'faceMask', 'kissHeart', 'lilSmile',
      'pissed', 'plain', 'sad', 'shout', 'shy', 'sick', 'smileLol', 'smileTeeth',
      'tongueOut', 'wideSmile',
    ],
    'lorelei':    ['variant01', 'variant02', 'variant03', 'variant04', 'variant05'],
    'pixel-art':  ['variant01', 'variant02', 'variant03', 'variant04', 'variant05'],
  };

  static const List<Map<String, String>> backgroundColors = [
    {'hex': 'b6e3f4', 'label': 'Sky Blue'},
    {'hex': 'ffdfbf', 'label': 'Peach'},
    {'hex': 'c0aede', 'label': 'Lavender'},
    {'hex': 'd1d4f9', 'label': 'Periwinkle'},
    {'hex': 'ffd5dc', 'label': 'Rose'},
    {'hex': 'c1e1c5', 'label': 'Mint'},
    {'hex': 'ffefd5', 'label': 'Cream'},
    {'hex': 'e0f2fe', 'label': 'Ice Blue'},
    {'hex': 'fce4ec', 'label': 'Blush'},
    {'hex': 'ede7f6', 'label': 'Soft Purple'},
    {'hex': 'f0fdf4', 'label': 'Pale Green'},
    {'hex': 'fff3e0', 'label': 'Soft Orange'},
    {'hex': 'e8eaf6', 'label': 'Indigo Tint'},
    {'hex': 'fdf6e3', 'label': 'Solarized'},
    {'hex': 'b2dfdb', 'label': 'Teal Light'},
    {'hex': '1a1a2e', 'label': 'Dark Navy'},
    {'hex': '16213e', 'label': 'Midnight'},
    {'hex': '0f3460', 'label': 'Deep Blue'},
    {'hex': '2d6a4f', 'label': 'Forest'},
    {'hex': '6b2d8b', 'label': 'Royal Purple'},
  ];

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  List<String> getOptionsForStyle(String category, String style) {
    switch (category) {
      case 'hair':  return hairOptions[style]  ?? [];
      case 'eyes':  return eyeOptions[style]   ?? [];
      case 'mouth': return mouthOptions[style] ?? [];
      default:      return [];
    }
  }

  bool styleSupports(String style, String category) =>
      getOptionsForStyle(category, style).isNotEmpty;

  String randomSeed({int length = 10}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String buildUrl(AvatarConfig config) => config.avatarUrl;

  AvatarConfig randomConfig({
    String style = 'adventurer',
    String backgroundColor = 'b6e3f4',
  }) =>
      AvatarConfig(seed: randomSeed(), style: style, backgroundColor: backgroundColor);

  /// Returns all 30 predefined configs, optionally filtered by [gender].
  List<AvatarConfig> predefinedConfigsFor(AvatarGender gender) {
    final entries = gender == AvatarGender.all
        ? predefinedEntries
        : predefinedEntries.where((e) {
            if (gender == AvatarGender.male) {
              return e['gender'] == 'male' || e['gender'] == 'neutral';
            }
            // female: female + neutral
            return e['gender'] == 'female' || e['gender'] == 'neutral';
          }).toList();

    return entries
        .map((e) => AvatarConfig(
              seed: e['seed']!,
              style: e['style']!,
              backgroundColor: e['bg']!,
            ))
        .toList();
  }

  /// Convenience getter — returns all 30.
  List<AvatarConfig> get predefinedConfigs => predefinedConfigsFor(AvatarGender.all);
}
