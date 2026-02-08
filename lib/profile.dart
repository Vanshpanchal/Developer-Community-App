import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/chatbot.dart';
import 'package:developer_community_app/saved_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/firebase_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'messagemodel.dart';

import 'chat.dart';
import 'portfolio.dart';
import 'api_key_manager.dart';
import 'screens/gamification_hub_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/ai_repo_analyzer_screen.dart';
import 'utils/app_theme.dart';
import 'package:palette_generator/palette_generator.dart';
import 'utils/app_snackbar.dart';

/// Menu item data model
class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class profile extends StatefulWidget {
  const profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<profile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String Xp = '';
  String? githubUsername;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Color? _dominantColor;

  Future<void> _updatePalette() async {
    if (imageUrl == null || imageUrl!.isEmpty) {
      if (mounted) setState(() => _dominantColor = null);
      return;
    }
    // Check if color is already cached
    final box = GetStorage();
    final cachedColor = box.read('profileColor');
    if (cachedColor != null) {
      if (mounted) {
        setState(() {
          _dominantColor = Color(cachedColor);
        });
      }
      return;
    }

    try {
      final PaletteGenerator generator =
          await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl!),
        maximumColorCount: 20,
      );
      if (mounted) {
        setState(() {
          _dominantColor = generator.dominantColor?.color;
        });
        // Cache the color
        if (_dominantColor != null) {
          box.write('profileColor', _dominantColor!.value);
        }
      }
    } catch (e) {
      debugPrint('Error generating palette: $e');
    }
  }

  /// Calculate text color based on background color luminance
  /// Returns white for dark backgrounds, black for light backgrounds
  Color _getAdaptiveTextColor(Color backgroundColor) {
    // Calculate luminance (0.0 - 1.0, where 0 is black and 1 is white)
    final luminance = backgroundColor.computeLuminance();
    
    // If background is dark (luminance < 0.5), use white text
    // If background is light (luminance >= 0.5), use dark text
    return luminance < 0.5 ? Colors.white : Colors.black87;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchuser();
    loadimage();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // fetchuser(); // Removed to prevent redundant fetching
  }

  signout() async {
    // Clear all cached data
    try {
      // 1. Clear Firestore Cache (GetStorage)
      final cacheService = FirebaseCacheService();
      await cacheService.clearAllCache();
      
      // 2. Clear API Key (Secure Storage)
      await ApiKeyManager.instance.clearKey();
      
      // 3. Clear Chat History (Hive)
      if (Hive.isBoxOpen('chat_messages')) {
        await Hive.box<Message>('chat_messages').clear();
      } else {
        await Hive.openBox<Message>('chat_messages').then((box) => box.clear());
      }
      
      debugPrint("🧹 All local data cleared successfully");
    } catch (e) {
      debugPrint("⚠️ Error clearing data: $e");
    }

    await FirebaseAuth.instance.signOut();
  }

  Future<void> _confirmLogout() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: AppTheme.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : Colors.black87,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await signout();
    }
  }

  forget() async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user!.email.toString());
      if (mounted) {
        AppSnackbar.success(
          'Check your inbox for password reset link',
          title: 'Email Sent',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.error(e.code, title: 'Error');
      }
    } catch (e) {
      debugPrint("Signupcode  {$e}");
    }
  }

  fetchuser() async {
    final box = GetStorage();
    final cached = box.read('userData');
    if (cached != null) {
      final data = cached as Map<String, dynamic>;
      setState(() {
        username = data['username'] ?? 'No name available';
        imageUrl = data['imageUrl'] ?? '';
        Xp = data['Xp'] ?? '0';
        githubUsername = data['githubUsername'];
      });
      final colorVal = data['profileColor'];
      if(colorVal != null) {
         if(mounted) {
             setState(() {
                 _dominantColor = Color(colorVal);
             });
         }
      }
      
      if(_dominantColor == null) {
          _updatePalette(); 
      }
    }
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('User')
          .doc(user?.uid)
          .get();
      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>?;
        final uname = data?['Username'] ?? 'No name available';
        final img = data?['profilePicture'] ?? '';
        final xp = data?['XP']?.toString() ?? '0';
        final github = data?['github'];
        setState(() {
          username = uname;
          imageUrl = img;
          Xp = xp;
          githubUsername = github;
        });
        _updatePalette();
        box.write('userData', {
          'username': uname,
          'imageUrl': img,
          'Xp': xp,
          'githubUsername': github
        });
      } else {
        setState(() {
          username = 'No name available';
        });
        box.write('userData', {
          'username': 'No name available',
          'imageUrl': '',
          'Xp': '0',
          'githubUsername': null
        });
      }
    }
  }

  String? imageUrl;
  final imagepicker = ImagePicker();
  bool isLoading = false;

  pickImage() async {
    XFile? res = await imagepicker.pickImage(source: ImageSource.gallery);
    if (res != null) {
      uploadProfilePic(File(res.path));
    }
  }

  uploadProfilePic(File file) async {
    try {
      String cloudName = 'dr0c1jgbe';
      String uploadPreset = 'profile_uploads';

      var url =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var jsonData = json.decode(responseData.body);
        String imageUrl = jsonData['secure_url'];

        await FirebaseFirestore.instance
            .collection('User')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'profilePicture': imageUrl});

        // Invalidate cached color when image changes
        final box = GetStorage();
        box.remove('profileColor');

        setState(() {
          this.imageUrl = imageUrl;
          _dominantColor = null; // Reset current color
        });
        _updatePalette();

        if (mounted) {
          AppSnackbar.success(
            'Profile picture updated',
            title: 'Success',
          );
        }
      } else {
        print('Failed to upload image to Cloudinary');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      if (mounted) {
        AppSnackbar.error(
          'Failed to upload image',
          title: 'Error',
        );
      }
    }
  }

  loadimage() async {}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    var usercredential = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              // physics: const BouncingScrollPhysics(),
              slivers: [
                // Modern Header
                SliverToBoxAdapter(
                  child: _buildProfileHeader(theme, isDark, usercredential),
                ),

                // Stats Card
                SliverToBoxAdapter(
                  child: _buildStatsCard(theme, isDark),
                ),

                // Menu Items
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      _buildSectionTitle(theme, 'Features'),
                      _buildMenuCard(theme, isDark, [
                        _MenuItemData(
                          icon: Icons.emoji_events_rounded,
                          title: 'Gamification Hub',
                          subtitle: 'Badges, challenges & rewards',
                          color: Colors.amber,
                          onTap: () => Get.to(const GamificationHubScreen()),
                        ),
                        _MenuItemData(
                          icon: Icons.leaderboard_rounded,
                          title: 'Leaderboard',
                          subtitle: 'See top contributors',
                          color: AppTheme.primaryColor,
                          onTap: () => Get.to(const LeaderboardScreen()),
                        ),
                        _MenuItemData(
                          icon: Icons.bookmark_rounded,
                          title: 'Saved Discussions',
                          subtitle: 'Your bookmarked content',
                          color: AppTheme.successColor,
                          onTap: () => Get.to(saved_discussion()),
                        ),
                        _MenuItemData(
                          icon: Icons.account_tree_rounded,
                          title: 'Your Activity',
                          subtitle: 'View your activity stats',
                          color: Colors.purple,
                          onTap: () => Get.to(const DeveloperPortfolioPage()),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle(theme, 'AI Tools'),
                      _buildMenuCard(theme, isDark, [
                        _MenuItemData(
                          icon: Icons.smart_toy_rounded,
                          title: 'Gemini Assistant',
                          subtitle: 'AI-powered coding help',
                          color: AppTheme.primaryColor,
                          onTap: () => Get.to(ChatScreen1()),
                        ),
                        _MenuItemData(
                          icon: Icons.code_rounded,
                          title: 'AI Repo Analyzer',
                          subtitle: 'Analyze GitHub repositories',
                          color: Colors.deepPurple,
                          onTap: () => Get.to(const AIRepoAnalyzerScreen()),
                        ),
                        _MenuItemData(
                          icon: Icons.vpn_key_rounded,
                          title: 'Set Gemini API Key',
                          subtitle: 'Configure your API access',
                          color: Colors.teal,
                          onTap: _setGeminiKey,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle(theme, 'Account'),
                      _buildMenuCard(theme, isDark, [
                        _MenuItemData(
                          icon: Icons.link_rounded,
                          title: githubUsername == null
                              ? 'Link GitHub'
                              : 'GitHub: $githubUsername',
                          subtitle: 'Connect your GitHub profile',
                          color: isDark ? Colors.white70 : Colors.black87,
                          onTap: _editGithub,
                        ),
                        _MenuItemData(
                          icon: Icons.camera_alt_rounded,
                          title: 'Change Profile Picture',
                          subtitle: 'Update your avatar',
                          color: AppTheme.primaryColor,
                          onTap: pickImage,
                        ),
                        _MenuItemData(
                          icon: Icons.lock_reset_rounded,
                          title: 'Reset Password',
                          subtitle: 'Change your password',
                          color: AppTheme.warningColor,
                          onTap: forget,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildLogoutButton(theme),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      ThemeData theme, bool isDark, User? usercredential) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _dominantColor != null
            ? LinearGradient(
                colors: [
                  _dominantColor!,
                  _dominantColor!.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        // boxShadow: [
        //   BoxShadow(
        //     color: AppTheme.primaryColor.withValues(alpha: 0.3),
        //     blurRadius: 20,
        //     // offset: const Offset(0, 10),
        //   ),
        // ],
      ),
      child: Stack(
        children: [
          // Decorative background elements
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: 20,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with edit button - Centered
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Colors.black.withValues(alpha: 0.2),
                        //     blurRadius: 10,
                        //     spreadRadius: 2,
                        //   ),
                        // ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage:
                            imageUrl != null && imageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(imageUrl!)
                                : const NetworkImage(
                                    'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                                  ) as ImageProvider,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Colors.black.withValues(alpha: 0.2),
                            //     blurRadius: 8,
                            //   ),
                            // ],
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Username
              Text(
                username.isNotEmpty ? username : 'Unknown User',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _getAdaptiveTextColor(_dominantColor ?? AppTheme.primaryColor),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                usercredential?.email ?? 'No email',
                style: TextStyle(
                  fontSize: 14,
                  color: _getAdaptiveTextColor(_dominantColor ?? AppTheme.primaryColor).withValues(alpha: 0.9),
                  letterSpacing: 0.2,
                ),
              ),const SizedBox(height: 16),

              // GitHub badge if linked
              if (githubUsername != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: _getAdaptiveTextColor(_dominantColor ?? AppTheme.primaryColor)),
                      const SizedBox(width: 6),
                      Text(
                        '@$githubUsername',
                        style: TextStyle(
                          color: _getAdaptiveTextColor(_dominantColor ?? AppTheme.primaryColor),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Trophy Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Stats Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Points',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      Xp.isNotEmpty ? Xp : '0',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View More
          IconButton(
            onPressed: () => Get.to(const GamificationHubScreen()),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      ThemeData theme, bool isDark, List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              _buildMenuItem(theme, isDark, item),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 64,
                  color:
                      isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(ThemeData theme, bool isDark, _MenuItemData item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppTheme.errorColor.withValues(alpha: 0.1),
            AppTheme.errorColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _confirmLogout,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppTheme.errorColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  uploadProfilePicFirebase(File file) async {
    try {
      Reference reference = FirebaseStorage.instance
          .ref('/Profile')
          .child('${FirebaseAuth.instance.currentUser?.uid}.png');

      await reference.putFile(file).whenComplete(() => {
            AppSnackbar.success('Profile Pic Changed')
          });

      imageUrl = await reference.getDownloadURL();
      setState(() {});
    } catch (e) {
      print('Error');
    }
  }

  Future<void> _editGithub() async {
    final controller = TextEditingController(text: githubUsername ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.code,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Link GitHub Account',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Enter your GitHub username to link your profile. This will display your GitHub stats and allow others to view your repositories.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              // Text Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'e.g. torvalds',
                  labelText: 'GitHub Username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final val = controller.text.trim();
                        Navigator.pop(ctx);
                        if (val.isEmpty) {
                          await FirebaseFirestore.instance
                              .collection('User')
                              .doc(user!.uid)
                              .update({'github': FieldValue.delete()});
                          setState(() => githubUsername = null);
                        } else {
                          await FirebaseFirestore.instance
                              .collection('User')
                              .doc(user!.uid)
                              .update({'github': val});
                          setState(() => githubUsername = val);
                        }
                        Get.showSnackbar(const GetSnackBar(
                          title: 'Saved',
                          message: 'GitHub updated',
                          duration: Duration(seconds: 2),
                        ));
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setGeminiKey() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key_rounded,
                          color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Gemini API Key',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  'Enter your Gemini API Key to enable AI-powered features. You can get your API key from Google AI Studio.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                // Text Field
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Paste your Gemini API Key',
                    labelText: 'API Key',
                    prefixIcon: const Icon(Icons.key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                  obscureText: true,
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a key';
                    if (!v.startsWith('AI')) return 'Key format looks unusual';
                    if (v.trim().length < 20) return 'Key too short';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final key = controller.text.trim();
                          Navigator.pop(ctx);
                          try {
                            await ApiKeyManager.instance.saveUserKey(key);
                            Get.showSnackbar(const GetSnackBar(
                                title: 'Saved',
                                message: 'Gemini key stored securely',
                                duration: Duration(seconds: 2)));
                          } catch (e) {
                            Get.showSnackbar(GetSnackBar(
                                title: 'Error',
                                message: e.toString(),
                                duration: const Duration(seconds: 3)));
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
