import 'dart:convert';

/// Model representing a complete DiceBear avatar configuration.
/// Supports multiple styles and optional customization parameters.
class AvatarConfig {
  final String seed;
  final String style;
  final String? hair;
  final String? eyes;
  final String? mouth;
  final String? accessories;
  final String? backgroundColor;
  final String? skinColor;

  const AvatarConfig({
    required this.seed,
    this.style = 'adventurer',
    this.hair,
    this.eyes,
    this.mouth,
    this.accessories,
    this.backgroundColor,
    this.skinColor,
  });

  /// Default avatar config used on reset.
  factory AvatarConfig.defaults() => const AvatarConfig(
        seed: 'DevSphere',
        style: 'adventurer',
        backgroundColor: 'b6e3f4',
      );

  /// Builds the full DiceBear v7 API URL from this config.
  String get avatarUrl {
    final buffer = StringBuffer(
      'https://api.dicebear.com/7.x/$style/png?seed=$seed',
    );

    if (backgroundColor != null && backgroundColor!.isNotEmpty) {
      buffer.write('&backgroundColor=$backgroundColor');
    }
    if (hair != null && hair!.isNotEmpty) {
      buffer.write('&hair=$hair');
    }
    if (eyes != null && eyes!.isNotEmpty) {
      buffer.write('&eyes=$eyes');
    }
    if (mouth != null && mouth!.isNotEmpty) {
      buffer.write('&mouth=$mouth');
    }
    if (accessories != null && accessories!.isNotEmpty) {
      buffer.write('&accessories=$accessories');
    }
    if (skinColor != null && skinColor!.isNotEmpty) {
      buffer.write('&skinColor=$skinColor');
    }

    return buffer.toString();
  }

  /// Serializes config to JSON map for persistence.
  Map<String, dynamic> toJson() => {
        'seed': seed,
        'style': style,
        if (hair != null) 'hair': hair,
        if (eyes != null) 'eyes': eyes,
        if (mouth != null) 'mouth': mouth,
        if (accessories != null) 'accessories': accessories,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (skinColor != null) 'skinColor': skinColor,
      };

  /// Deserializes config from JSON map.
  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        seed: json['seed'] as String? ?? 'DevSphere',
        style: json['style'] as String? ?? 'adventurer',
        hair: json['hair'] as String?,
        eyes: json['eyes'] as String?,
        mouth: json['mouth'] as String?,
        accessories: json['accessories'] as String?,
        backgroundColor: json['backgroundColor'] as String?,
        skinColor: json['skinColor'] as String?,
      );

  /// JSON string representation for sharing / storing in GetStorage.
  String toJsonString() => jsonEncode(toJson());

  /// Parses from a JSON string.
  factory AvatarConfig.fromJsonString(String jsonStr) =>
      AvatarConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  /// Returns a copy of this config with specified fields overridden.
  AvatarConfig copyWith({
    String? seed,
    String? style,
    String? hair,
    String? eyes,
    String? mouth,
    String? accessories,
    String? backgroundColor,
    String? skinColor,
    bool clearHair = false,
    bool clearEyes = false,
    bool clearMouth = false,
    bool clearAccessories = false,
  }) =>
      AvatarConfig(
        seed: seed ?? this.seed,
        style: style ?? this.style,
        hair: clearHair ? null : (hair ?? this.hair),
        eyes: clearEyes ? null : (eyes ?? this.eyes),
        mouth: clearMouth ? null : (mouth ?? this.mouth),
        accessories:
            clearAccessories ? null : (accessories ?? this.accessories),
        backgroundColor: backgroundColor ?? this.backgroundColor,
        skinColor: skinColor ?? this.skinColor,
      );

  @override
  String toString() => 'AvatarConfig(seed: $seed, style: $style, url: $avatarUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarConfig &&
          runtimeType == other.runtimeType &&
          seed == other.seed &&
          style == other.style &&
          hair == other.hair &&
          eyes == other.eyes &&
          mouth == other.mouth &&
          accessories == other.accessories &&
          backgroundColor == other.backgroundColor &&
          skinColor == other.skinColor;

  @override
  int get hashCode => Object.hash(
        seed,
        style,
        hair,
        eyes,
        mouth,
        accessories,
        backgroundColor,
        skinColor,
      );
}
