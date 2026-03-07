import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'models/poll_model.dart';
import 'widgets/poll_widgets.dart';
import 'services/gamification_service.dart';
import 'models/gamification_models.dart';
import 'utils/app_snackbar.dart';
import 'utils/app_validators.dart';

class add_discussion extends StatefulWidget {
  add_discussion({super.key});

  @override
  State<add_discussion> createState() => _add_discussionState();
}

class _add_discussionState extends State<add_discussion> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String markdownContent = ''; // Markdown content for Preview
  String code = ''; // Code content to show in the 'Code' tab

  // Poll support
  bool _showPollCreator = false;
  PollCreationData? _pollData;
  final _gamificationService = GamificationService();

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  String? selectedSubject;
  Future<void> shareDiscussion() async {
      if (!_formKey.currentState!.validate()) {
        AppSnackbar.error("Please fix the errors in the form.");
        return;
      }
      if (_tags.isEmpty) {
        AppSnackbar.error("Please add at least one tag.");
        return;
      }

      setState(() => _isLoading = true);
      
      try {
      // Get the current user
      var user = FirebaseAuth.instance.currentUser;

      // Generate document ID for the discussion
      String docId =
          FirebaseFirestore.instance.collection('Discussions').doc().id;

      // Prepare data to be stored
      Map<String, dynamic> data = {
        'Title': _titleController.text.trim().capitalizeFirst,
        'Description': _descriptionController.text.trim().capitalizeFirst,
        'Uid': user?.uid,
        'Report': false,
        'Tags': _tags,
        'docId': docId,
        'Timestamp': FieldValue.serverTimestamp(),
        'Replies': [], // Initialize an empty array for replies
        'hasPoll': _pollData != null && _pollData!.isValid,
      };

      // Add poll data if exists
      if (_pollData != null && _pollData!.isValid && user != null) {
        final poll = _pollData!.toPoll(user.uid);
        data['poll'] = poll.toMap();
      }

      // Add data to Firestore for the discussion
      await FirebaseFirestore.instance
          .collection("Discussions")
          .doc(docId)
          .set(data);

      debugPrint("Discussion Created");

      // Award XP for creating discussion
      await _gamificationService.awardXp(XpAction.createDiscussion);
      await _gamificationService.recordActivity();

      // Award XP for poll if created
      if (_pollData != null && _pollData!.isValid) {
        await _gamificationService.awardXp(XpAction.pollCreated);
        await _gamificationService.incrementCounter('pollsCreated');
      }

      AppSnackbar.success("Success! +${XpAction.createDiscussion.defaultXp} XP", title: "Discussion Created");

      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      AppSnackbar.error(e.message ?? 'An error occurred', title: 'Authentication Error');
    } catch (e) {
      debugPrint("ShareDiscussion Error: {$e}");
      AppSnackbar.error(e.toString(), title: "Error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];

  void _addTag() {
    final tag = _tagController.text.toUpperCase().trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      print(_tags);
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Discussion Preview',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Title
                        if (_titleController.text.trim().isNotEmpty) ...[
                          Text(
                            _titleController.text.trim(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                        ],
                        // Description
                        if (_descriptionController.text.trim().isNotEmpty) ...[
                          Text(
                            _descriptionController.text.trim(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Tags
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _tags.map((tag) {
                              return Chip(
                                label: Text(
                                  tag,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Poll Preview
                        if (_pollData != null && _pollData!.isValid) ...[
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.poll,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Poll',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pollData!.question,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...(_pollData!.options
                                    .where((o) => o.isNotEmpty)
                                    .map((option) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.radio_button_unchecked,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(option),
                                      ],
                                    ),
                                  );
                                })),
                              ],
                            ),
                          ),
                        ],
                        // Empty state
                        if (_titleController.text.trim().isEmpty &&
                            _descriptionController.text.trim().isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Start writing to see preview',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Discussion'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _showPreview,
            tooltip: 'Preview Discussion',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondary
                    .withValues(alpha: isDark ? 0.3 : 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.secondary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.forum_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Start a meaningful discussion with the community",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title Field
                Text(
                  'Title',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  validator: AppValidators.validateTitle,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'What do you want to discuss?',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description Field
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  validator: AppValidators.validateDescription,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  maxLines: 8,
                  minLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Provide context and details...',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    alignLabelWithHint: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tags Field
                Text(
                  'Tags',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                FormField<List<String>>(
                  validator: (value) {
                    if (_tags.isEmpty) {
                      return 'Please add at least one tag.';
                    }
                    return null;
                  },
                  builder: (FormFieldState<List<String>> state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          textCapitalization: TextCapitalization.characters,
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: 'Add relevant tags (e.g., FLUTTER, DART)',
                            prefixIcon: Icon(
                              Icons.tag_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                _addTag();
                                state.validate();
                              },
                              tooltip: 'Add tag',
                            ),
                            errorText: state.hasError ? state.errorText : null,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) {
                            _addTag();
                            state.validate();
                          },
                        ),
                        // Tags Display
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _tags.map((tag) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary.withValues(alpha: 0.15),
                                      theme.colorScheme.secondary
                                          .withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Chip(
                                  label: Text(
                                    tag,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: Colors.transparent,
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onDeleted: () {
                                    _removeTag(tag);
                                    state.validate();
                                  },
                                  elevation: 0,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                ),


                const SizedBox(height: 24),

                // Poll Section
                if (!_showPollCreator && _pollData == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.poll_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Make it interactive',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a poll to gather community opinions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showPollCreator = true;
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Poll'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_showPollCreator)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: CreatePollWidget(
                      onPollCreated: (pollData) {
                        setState(() {
                          _pollData = pollData;
                          _showPollCreator = false;
                        });
                      },
                      onCancel: () {
                        setState(() {
                          _showPollCreator = false;
                        });
                      },
                    ),
                  ),

                if (_pollData != null && !_showPollCreator)
                  Container(
                    margin: const EdgeInsets.only(top: 0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.secondary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.poll,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        _pollData!.question,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${_pollData!.options.where((o) => o.isNotEmpty).length} options',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPollCreator = true;
                              });
                            },
                            tooltip: 'Edit poll',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () {
                              setState(() {
                                _pollData = null;
                              });
                            },
                            tooltip: 'Remove poll',
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Preview Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.visibility),
                    label: const Text(
                      'Preview Discussion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : shareDiscussion,
                    icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send_rounded),
                    label: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5,))
                        : const Text(
                            'Start Discussion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
  