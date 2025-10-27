import 'package:flutter/material.dart';
import 'package:flutter_app/views/pages/edit_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final title = 'Profile Page';

  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;
  String? currentUserId; // 💡 NEW: Store the user ID

  @override
  void initState() {
    super.initState();
    _loadProfileAndPosts();
  }

  // Combines loading the profile and posts for the initial load and refresh
  Future<void> _loadProfileAndPosts() async {
    if (!mounted) return;
    
    await _loadProfile();
    
    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts();
      });
    }
  }

  // --- Profile Loading ---
  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      currentUserId = user.id; // 💡 Set the user ID

      final response = await supabase
          .from('profile')
          .select('avatar_url, username, bio')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        avatarUrl = response?['avatar_url'];
        username = response?['username'] ?? 'Unknown User';
        bio = response?['bio'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- Posts Loading ---
  Future<List<Map<String, dynamic>>> _fetchUserPosts() async {
    // Use the stored ID, which is safer than relying on currentAuthUser during navigation
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final posts = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      // ⚠️ FREEZE FIX: If navigation occurred while query was running, abort processing.
      if (!mounted) return []; 

      return List<Map<String, dynamic>>.from(posts);
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
      return Future.error('Failed to load posts');
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  // --- Widget for a Single Post Card ---
  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'] as String?;
    final createdAt = post['created_at'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Content and Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16, right: 16, bottom: 8),
            child: Text(
              createdAt != ''
                  ? DateTime.parse(createdAt)
                      .toLocal()
                      .toString()
                      .substring(0, 16)
                  : 'Just now',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          
          // Image Display (If present)
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: Text('Image failed to load 😔', style: TextStyle(color: Colors.red)),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileAndPosts,
              child: ListView(
                children: [
                  // --- 1. PROFILE HEADER SECTION ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: (avatarUrl == null || avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Username
                        Text(
                          username ?? 'Loading...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Bio
                        Text(
                          bio ?? 'No bio yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        // Edit Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
                            await _loadProfileAndPosts(); // Refresh profile AND posts
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),

                        const Divider(height: 40),
                        
                        // Section Header
                        const Text(
                          'Your Posts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // --- 2. USER POSTS FEED SECTION ---
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _userPostsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error loading posts: ${snapshot.error}'),
                          ),
                        );
                      }

                      final userPosts = snapshot.data ?? [];
                      if (userPosts.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('You haven\'t posted anything yet.'),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: userPosts.map(_buildPostCard).toList(),
                        ),
                      );
                    },
                  ),
                  
                  // Logout option
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: _logout,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}