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

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '📊 Create Poll',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Question
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Ask a question...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // Options
            const Text(
              'Options',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            ..._optionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLength: 100,
                        buildCounter: (_,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red,
                        onPressed: () => _removeOption(index),
                      ),
                  ],
                ),
              );
            }),

            if (_optionControllers.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
              ),

            const Divider(height: 24),

            // Settings
            SwitchListTile(
              title: const Text('Allow multiple votes'),
              subtitle: const Text('Users can select more than one option'),
              value: _allowMultipleVotes,
              onChanged: (v) => setState(() => _allowMultipleVotes = v),
              dense: true,
            ),

            SwitchListTile(
              title: const Text('Anonymous voting'),
              subtitle: const Text('Hide voter identities'),
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              dense: true,
            ),

            SwitchListTile(
              title: const Text('Show results before voting'),
              subtitle: const Text('Users can see results without voting'),
              value: _showResultsBeforeVoting,
              onChanged: (v) => setState(() => _showResultsBeforeVoting = v),
              dense: true,
            ),

            // End date
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Poll ends at'),
              subtitle: Text(
                _endsAt != null
                    ? '${_endsAt!.day}/${_endsAt!.month}/${_endsAt!.year} ${_endsAt!.hour}:${_endsAt!.minute.toString().padLeft(2, '0')}'
                    : 'No end date (runs forever)',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endsAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endsAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectEndDate,
                  ),
                ],
              ),
              dense: true,
            ),

            const SizedBox(height: 16),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createPoll,
                icon: const Icon(Icons.poll),
                label: const Text('Create Poll'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Ended',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                if (widget.poll.allowMultipleVotes)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Multiple choice',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.poll.totalVotes} votes',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
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
                            : Colors.grey[300]!,
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
                                      : Colors.grey,
                                ),
                              if (!_canSeeResults) const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
                                        : Colors.grey[600],
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
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Ends ${_formatDate(widget.poll.endsAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
