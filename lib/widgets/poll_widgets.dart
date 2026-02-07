import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poll_model.dart';
import '../services/poll_service.dart';

/// Widget to create a new poll
class CreatePollWidget extends StatefulWidget {
  final Function(PollCreationData) onPollCreated;
  final VoidCallback? onCancel;

  const CreatePollWidget({
    super.key,
    required this.onPollCreated,
    this.onCancel,
  });

  @override
  State<CreatePollWidget> createState() => _CreatePollWidgetState();
}

class _CreatePollWidgetState extends State<CreatePollWidget> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultipleVotes = false;
  bool _isAnonymous = false;
  bool _showResultsBeforeVoting = false;
  DateTime? _endsAt;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  void _selectEndDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );

      if (time != null) {
        setState(() {
          _endsAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _createPoll() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question')),
      );
      return;
    }

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 options')),
      );
      return;
    }

    final pollData = PollCreationData(
      question: question,
      options: options,
      endsAt: _endsAt,
      allowMultipleVotes: _allowMultipleVotes,
      isAnonymous: _isAnonymous,
      showResultsBeforeVoting: _showResultsBeforeVoting,
    );

    widget.onPollCreated(pollData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.poll_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Create Poll',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (widget.onCancel != null)
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: widget.onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Question
        Text(
          'Question',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _questionController,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Ask a question...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.help_outline,
              color: theme.colorScheme.primary,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 12,
            ),
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
          maxLength: 200,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
        ),
        const SizedBox(height: 20),

        // Options
        Text(
          'Options',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        ..._optionControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          final isEmpty = controller.text.trim().isEmpty;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(
                milliseconds: 300 + (index * 50)), // Staggered animation
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isEmpty
                              ? theme.colorScheme.outline.withValues(alpha: 0.1)
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: isEmpty
                            ? null
                            : [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Option number badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isEmpty
                                  ? theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.1)
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isEmpty
                                    ? theme.colorScheme.outline
                                        .withValues(alpha: 0.2)
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: isEmpty
                                  ? Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : Icon(
                                      Icons.check,
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text input
                          Expanded(
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                setState(
                                    () {}); // Trigger rebuild for focus states
                              },
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Enter option ${index + 1}',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                ),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLength: 100,
                                buildCounter: (_,
                                        {required currentLength,
                                        required isFocused,
                                        maxLength}) =>
                                    null,
                                onChanged: (value) {
                                  setState(
                                      () {}); // Trigger rebuild for visual updates
                                },
                              ),
                            ),
                          ),

                          // Remove button (only show if more than 2 options)
                          if (_optionControllers.length > 2)
                            Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.remove,
                                  color: theme.colorScheme.error,
                                  size: 16,
                                ),
                                onPressed: () => _removeOption(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Remove option',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),

        // Add option button
        if (_optionControllers.length < 6)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: InkWell(
                    onTap: _addOption,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Option',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // Options count indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_optionControllers.length} of 6 options',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Settings
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Allow multiple votes
              Row(
                children: [
                  Icon(
                    _allowMultipleVotes
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: _allowMultipleVotes
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multiple votes',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Allow selecting multiple options',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowMultipleVotes,
                    onChanged: (v) => setState(() => _allowMultipleVotes = v),
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Anonymous voting
              Row(
                children: [
                  Icon(
                    _isAnonymous ? Icons.visibility_off : Icons.visibility,
                    color: _isAnonymous
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anonymous',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Hide voter identities',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAnonymous,
                    onChanged: (v) => setState(() => _isAnonymous = v),
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Show results before voting
              Row(
                children: [
                  Icon(
                    _showResultsBeforeVoting
                        ? Icons.bar_chart
                        : Icons.bar_chart_outlined,
                    color: _showResultsBeforeVoting
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show results first',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'View results without voting',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showResultsBeforeVoting,
                    onChanged: (v) =>
                        setState(() => _showResultsBeforeVoting = v),
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // End date
        InkWell(
          onTap: _selectEndDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Poll Duration',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _endsAt != null
                            ? '${_endsAt!.day}/${_endsAt!.month}/${_endsAt!.year} at ${_endsAt!.hour}:${_endsAt!.minute.toString().padLeft(2, '0')}'
                            : 'No end date (runs forever)',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_endsAt != null)
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: theme.colorScheme.error,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _endsAt = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Create button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _createPoll,
            icon: Icon(
              Icons.poll,
              color: theme.colorScheme.onPrimary,
            ),
            label: Text(
              'Create Poll',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget to display and interact with a poll
class PollDisplayWidget extends StatefulWidget {
  final Poll poll;
  final String parentId;
  final String parentCollection;
  final VoidCallback? onVoted;
  final bool canDelete;
  final VoidCallback? onDelete;

  const PollDisplayWidget({
    super.key,
    required this.poll,
    required this.parentId,
    required this.parentCollection,
    this.onVoted,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  State<PollDisplayWidget> createState() => _PollDisplayWidgetState();
}

class _PollDisplayWidgetState extends State<PollDisplayWidget> {
  final _pollService = PollService();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _voting = false;
  Set<String> _selectedOptions = {};

  bool get _hasVoted => widget.poll.hasUserVoted(_currentUserId ?? '');
  bool get _canSeeResults =>
      _hasVoted || widget.poll.showResultsBeforeVoting || widget.poll.isExpired;

  @override
  void initState() {
    super.initState();
    // Pre-select user's existing votes
    if (_currentUserId != null) {
      _selectedOptions = widget.poll.getUserVotes(_currentUserId!).toSet();
    }
  }

  Future<void> _vote(String optionId) async {
    if (_voting || widget.poll.isExpired) return;
    if (!widget.poll.allowMultipleVotes && _hasVoted) return;

    setState(() => _voting = true);
    try {
      final success = await _pollService.vote(
        pollId: widget.poll.id,
        optionId: optionId,
        parentId: widget.parentId,
        parentCollection: widget.parentCollection,
      );

      if (success) {
        setState(() {
          _selectedOptions.add(optionId);
        });
        widget.onVoted?.call();
      }
    } finally {
      setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.poll.question,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (widget.canDelete)
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Poll'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        widget.onDelete?.call();
                      }
                    },
                  ),
              ],
            ),

            // Status badges
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (widget.poll.isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ended',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (widget.poll.allowMultipleVotes)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Multiple choice',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.poll.totalVotes} votes',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Options
            ...widget.poll.options.map((option) {
              final isSelected = _selectedOptions.contains(option.id);
              final percentage = widget.poll.getOptionPercentage(option.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _canSeeResults || _voting || widget.poll.isExpired
                      ? null
                      : () => _vote(option.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // Progress bar (only show if can see results)
                        if (_canSeeResults)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              if (!_canSeeResults)
                                Icon(
                                  widget.poll.allowMultipleVotes
                                      ? (isSelected
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank)
                                      : (isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off),
                                  size: 20,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              if (!_canSeeResults) const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (_canSeeResults)
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Expiry info
            if (widget.poll.endsAt != null && !widget.poll.isExpired)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Ends ${_formatDate(widget.poll.endsAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays > 0) {
      return 'in ${diff.inDays} days';
    } else if (diff.inHours > 0) {
      return 'in ${diff.inHours} hours';
    } else if (diff.inMinutes > 0) {
      return 'in ${diff.inMinutes} minutes';
    }
    return 'soon';
  }
}

/// Compact poll button to add poll to a post/discussion
class AddPollButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddPollButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.poll_outlined),
      label: const Text('Add Poll'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
