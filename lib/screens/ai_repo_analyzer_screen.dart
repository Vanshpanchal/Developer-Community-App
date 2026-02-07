import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_theme.dart';
import '../ai_service.dart';
import '../ThemeController.dart';
import '../utils/app_snackbar.dart';

class AIRepoAnalyzerScreen extends StatefulWidget {
  const AIRepoAnalyzerScreen({Key? key}) : super(key: key);

  @override
  State<AIRepoAnalyzerScreen> createState() => _AIRepoAnalyzerScreenState();
}

class _AIRepoAnalyzerScreenState extends State<AIRepoAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  final _repoUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _analyzing = false;
  String? _analysisResult;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _analyzeRepository() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _analyzing = true;
      _analysisResult = null;
    });

    try {
      final url = _repoUrlController.text.trim();
      final analysis = await AIService().analyzeRepository(repoUrl: url);

      if (mounted) {
        setState(() {
          _analysisResult = analysis;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        AppSnackbar.error(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.code_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Repo Analyzer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              ),
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              _buildHeaderCard(theme, isDark),
              const SizedBox(height: 24),

              // Input Form
              _buildInputForm(theme, isDark),
              const SizedBox(height: 24),

              // Analyze Button
              _buildAnalyzeButton(theme, isDark),
              const SizedBox(height: 24),

              // Analysis Result
              if (_analysisResult != null) _buildResultCard(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark) {
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.15),
            primaryColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyze GitHub Repository',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get AI-powered insights about code structure, dependencies, and best practices',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm(ThemeData theme, bool isDark) {
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Repository URL',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repoUrlController,
              decoration: InputDecoration(
                hintText: 'https://github.com/username/repository',
                prefixIcon: Icon(Icons.code, color: primaryColor),
                filled: true,
                fillColor: isDark
                    ? AppTheme.darkSurface
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a repository URL';
                }
                if (!value.contains('github.com')) {
                  return 'Please enter a valid GitHub URL';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(ThemeData theme, bool isDark) {
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _analyzing ? null : _analyzeRepository,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _analyzing ? 0 : 4,
        ),
        child: _analyzing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_fix_high_rounded),
                  SizedBox(width: 8),
                  Text(
                    'Analyze Repository',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, bool isDark) {
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Analysis Result',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _analysisResult!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
