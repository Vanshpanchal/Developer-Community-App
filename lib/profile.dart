import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/chatbot.dart';
import 'package:developer_community_app/saved_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'chat.dart';
import 'portfolio.dart';
import 'api_key_manager.dart';
import 'screens/gamification_hub_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'utils/app_theme.dart';

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

class _ProfileState extends State<profile> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String Xp = '';
  String? githubUsername;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    fetchuser();
  }

  signout() async {
    await FirebaseAuth.instance.signOut();
  }

  forget() async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user!.email.toString());
      if (mounted) {
        AppSnackbar.success(
          context,
          title: 'Email Sent',
          message: 'Check your inbox for password reset link',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.error(context, title: 'Error', message: e.code);
      }
    } catch (e) {
      debugPrint("Signupcode  {$e}");
    }
  }

  fetchuser() async {
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('User')
          .doc(user?.uid)
          .get();
      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>?;
        setState(() {
          username = data?['Username'] ?? 'No name available';
          imageUrl = data?['profilePicture'] ?? '';
          Xp = data?['XP']?.toString() ?? '0';
          githubUsername = data?['github'];
        });
      } else {
        setState(() {
          username = 'No name available';
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
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .update({'profilePicture': imageUrl});

        setState(() {
          this.imageUrl = imageUrl;
        });

        if (mounted) {
          AppSnackbar.success(
            context,
            title: 'Success',
            message: 'Profile picture updated',
          );
        }
      } else {
        print('Failed to upload image to Cloudinary');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      if (mounted) {
        AppSnackbar.error(
          context,
          title: 'Error',
          message: 'Failed to upload image',
        );
      }
    }
  }

  loadimage() async {}

  @override
  Widget build(BuildContext context) {
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
              physics: const BouncingScrollPhysics(),
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
                          icon: Icons.account_tree_rounded,
                          title: 'AI Portfolio',
                          subtitle: 'Generate your portfolio',
                          color: Colors.purple,
                          onTap: () => Get.to(const DeveloperPortfolioPage()),
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
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with edit button
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : const NetworkImage(
                          'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                        ),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
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
          const SizedBox(height: 16),

          // Username
          Text(
            username.isNotEmpty ? username : 'Unknown User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            usercredential?.email ?? 'No email',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),

          // GitHub badge if linked
          if (githubUsername != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '@$githubUsername',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
          onTap: signout,
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
            Get.showSnackbar(GetSnackBar(
              title: "Success",
              message: "Profile Pic Changed",
              icon: const Icon(
                Icons.bookmark,
                color: Colors.green,
              ),
              mainButton: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Ok',
                    style: TextStyle(color: Colors.white),
                  )),
              duration: const Duration(seconds: 2),
            ))
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

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.code, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('GitHub Username'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. torvalds',
            labelText: 'Username',
            prefixIcon: const Icon(Icons.alternate_email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                  duration: Duration(seconds: 2)));
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Future<void> _setGeminiKey() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
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
            const Text('Gemini API Key'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Paste your Gemini API Key',
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a key';
              if (!v.startsWith('AI')) return 'Key format looks unusual';
              if (v.trim().length < 20) return 'Key too short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
          )
        ],
      ),
    );
  }
}
