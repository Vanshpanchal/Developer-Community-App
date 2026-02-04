/// Poll model for DevSphere discussions

class PollOption {
  final String id;
  final String text;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
  });

  int get voteCount => voterIds.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'voterIds': voterIds,
      };

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
        id: map['id'] ?? '',
        text: map['text'] ?? '',
        voterIds: List<String>.from(map['voterIds'] ?? []),
      );

  PollOption copyWith({
    String? id,
    String? text,
    List<String>? voterIds,
  }) =>
      PollOption(
        id: id ?? this.id,
        text: text ?? this.text,
        voterIds: voterIds ?? this.voterIds,
      );
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? endsAt;
  final bool allowMultipleVotes;
  final bool isAnonymous;
  final bool showResultsBeforeVoting;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.creatorId,
    required this.createdAt,
    this.endsAt,
    this.allowMultipleVotes = false,
    this.isAnonymous = false,
    this.showResultsBeforeVoting = false,
  });

  int get totalVotes {
    final uniqueVoters = <String>{};
    for (final option in options) {
      uniqueVoters.addAll(option.voterIds);
    }
    return allowMultipleVotes
        ? options.fold(0, (sum, opt) => sum + opt.voteCount)
        : uniqueVoters.length;
  }

  bool get isExpired {
    if (endsAt == null) return false;
    return DateTime.now().isAfter(endsAt!);
  }

  bool get isActive => !isExpired;

  bool hasUserVoted(String odId) {
    return options.any((opt) => opt.voterIds.contains(odId));
  }

  String? getUserVote(String odId) {
    for (final option in options) {
      if (option.voterIds.contains(odId)) {
        return option.id;
      }
    }
    return null;
  }

  List<String> getUserVotes(String odId) {
    return options
        .where((opt) => opt.voterIds.contains(odId))
        .map((opt) => opt.id)
        .toList();
  }

  double getOptionPercentage(String optionId) {
    if (totalVotes == 0) return 0;
    final option = options.firstWhere(
      (o) => o.id == optionId,
      orElse: () => const PollOption(id: '', text: ''),
    );
    return (option.voteCount / totalVotes) * 100;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        'creatorId': creatorId,
        'createdAt': createdAt.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'allowMultipleVotes': allowMultipleVotes,
        'isAnonymous': isAnonymous,
        'showResultsBeforeVoting': showResultsBeforeVoting,
      };

  factory Poll.fromMap(Map<String, dynamic> map) => Poll(
        id: map['id'] ?? '',
        question: map['question'] ?? '',
        options: (map['options'] as List<dynamic>?)
                ?.map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
                .toList() ??
            [],
        creatorId: map['creatorId'] ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        endsAt: map['endsAt'] != null ? DateTime.tryParse(map['endsAt']) : null,
        allowMultipleVotes: map['allowMultipleVotes'] ?? false,
        isAnonymous: map['isAnonymous'] ?? false,
        showResultsBeforeVoting: map['showResultsBeforeVoting'] ?? false,
      );

  Poll copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    String? creatorId,
    DateTime? createdAt,
    DateTime? endsAt,
    bool? allowMultipleVotes,
    bool? isAnonymous,
    bool? showResultsBeforeVoting,
  }) =>
      Poll(
        id: id ?? this.id,
        question: question ?? this.question,
        options: options ?? this.options,
        creatorId: creatorId ?? this.creatorId,
        createdAt: createdAt ?? this.createdAt,
        endsAt: endsAt ?? this.endsAt,
        allowMultipleVotes: allowMultipleVotes ?? this.allowMultipleVotes,
        isAnonymous: isAnonymous ?? this.isAnonymous,
        showResultsBeforeVoting:
            showResultsBeforeVoting ?? this.showResultsBeforeVoting,
      );
}

// Poll creation helper
class PollCreationData {
  String question;
  List<String> options;
  DateTime? endsAt;
  bool allowMultipleVotes;
  bool isAnonymous;
  bool showResultsBeforeVoting;

  PollCreationData({
    this.question = '',
    List<String>? options,
    this.endsAt,
    this.allowMultipleVotes = false,
    this.isAnonymous = false,
    this.showResultsBeforeVoting = false,
  }) : options = options ?? ['', ''];

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.where((o) => o.trim().isNotEmpty).length >= 2;

  Poll toPoll(String odId) {
    final pollId = DateTime.now().millisecondsSinceEpoch.toString();
    return Poll(
      id: pollId,
      question: question.trim(),
      options: options
          .where((o) => o.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map((e) => PollOption(
                id: '${pollId}_${e.key}',
                text: e.value.trim(),
              ))
          .toList(),
      creatorId: odId,
      createdAt: DateTime.now(),
      endsAt: endsAt,
      allowMultipleVotes: allowMultipleVotes,
      isAnonymous: isAnonymous,
      showResultsBeforeVoting: showResultsBeforeVoting,
    );
  }
}
