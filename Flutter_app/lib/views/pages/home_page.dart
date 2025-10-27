import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/views/pages/guest_profile_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final title = 'Home Page';

  late final Stream<List<Map<String, dynamic>>> _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = _getRealtimePosts();
  }

  /// Creates a realtime stream of posts and joins with profile info
  Stream<List<Map<String, dynamic>>> _getRealtimePosts() {
    return supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((posts) async {
      if (posts.isEmpty) return posts;

      // Collect unique user IDs
      final userIds = posts.map((p) => p['user_id']).toSet().toList();

      // Fetch all related profiles in a single query
      final profiles = await supabase
          .from('profile')
          .select('id, username, avatar_url')
          .inFilter('id', userIds);

      // Map each user_id to their profile
      final profileMap = {
        for (var p in profiles) p['id']: p,
      };

      // Attach profiles to posts
      for (final post in posts) {
        post['profile'] = profileMap[post['user_id']];
      }

      return posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading posts: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet. Be the first to share something!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _postsStream = _getRealtimePosts(); // reload stream manually
              });
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final profile = post['profile'] ?? {};
                final username = profile['username'] ?? 'Unknown';
                final avatarUrl = profile['avatar_url'];
                final content = post['content'] ?? '';
                final imageUrl = post['image_url'] as String?; // Cast as String? for safety
                final createdAt = post['created_at'] ?? '';
                // The ID of the post author
                final userId = post['user_id'] as String?; 

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // USER INFO AND TEXT CONTENT 
                      ListTile(
                        // 💡 ADD onTap TO NAVIGATE TO THE GUEST PROFILE PAGE
                        onTap: () {
                          if (userId != null && userId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GuestProfilePage(
                                  userId: userId, // Pass the author's user ID
                                ),
                              ),
                            );
                          }
                        },
                        
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl != null && avatarUrl != ''
                              ? NetworkImage(avatarUrl)
                              : const AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                        ),
                        title: Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(content),
                        ),
                        trailing: Text(
                          createdAt != ''
                              ? DateTime.parse(createdAt)
                                  .toLocal()
                                  .toString()
                                  .substring(0, 16)
                              : '',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      
                      // 🖼️ Image Display 
                      if (imageUrl != null && imageUrl.isNotEmpty) 
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              // Add headers for cache control (optional, but good practice)
                              headers: const {'accept': 'image/*'}, 
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    height: 150, // Give it a placeholder height
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                // Print the error to the console for debugging
                                debugPrint('Image load failed for URL: $imageUrl. Error: $error');
                                return const SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: Text('Failed to load image 😔'),
                                  ),
=======
                        child: ListView.builder(
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                                final post = posts[index];
                                final postId = post['id'] as String;
                                final profile = post['profile'] ?? {};
                                final username = profile['username'] ?? 'Unknown';
                                final avatarUrl = profile['avatar_url'];
                                final content = post['content'] ?? '';
                                final imageUrl = post['image_url'] as String?;
                                final createdAt = post['created_at'] ?? '';
                                final userId = post['user_id'] as String?;

                                final int likeCount = post['like_count'] as int? ?? 0;
                                final bool userLiked = post['user_liked'] as bool? ?? false;

                                return Card(
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // User info and text content
                                            ListTile(
                                                onTap: () {
                                                    if (userId != null && userId.isNotEmpty) {
                                                        Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder: (context) => GuestProfilePage(
                                                                    userId: userId,
                                                                ),
                                                            ),
                                                        );
                                                    }
                                                },
                                                leading: CircleAvatar(
                                                    backgroundImage: avatarUrl != null && avatarUrl != ''
                                                        ? NetworkImage(avatarUrl)
                                                        : const AssetImage('assets/default_avatar.png')
                                                                as ImageProvider,
                                                ),
                                                title: Text(
                                                    username,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                    ),
                                                ),
                                                subtitle: Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text(content),
                                                ),
                                                trailing: Text(
                                                    createdAt != ''
                                                        ? DateTime.parse(createdAt)
                                                                .toLocal()
                                                                .toString()
                                                                .substring(0, 16)
                                                        : '',
                                                    style:
                                                        const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                            ),

                                            // Image display
                                            if (imageUrl != null && imageUrl.isNotEmpty)
                                                Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                                    child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8.0),
                                                        child: Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            width: double.infinity,
                                                            loadingBuilder: (context, child, loadingProgress) {
                                                                if (loadingProgress == null) return child;
                                                                return const SizedBox(
                                                                    height: 150,
                                                                    child: Center(child: CircularProgressIndicator()),
                                                                );
                                                            },
                                                            errorBuilder: (context, error, stackTrace) {
                                                                debugPrint('Image load failed for URL: $imageUrl. Error: $error');
                                                                return const SizedBox(
                                                                    height: 150,
                                                                    child: Center(
                                                                        child: Text('Failed to load image'),
                                                                    ),
                                                                );
                                                            },
                                                        ),
                                                    ),
                                                ),

                                            // Like button and count
                                            Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                child: Row(
                                                    children: [
                                                        IconButton(
                                                            icon: Icon(
                                                                userLiked ? Icons.favorite : Icons.favorite_border,
                                                                color: userLiked ? Colors.red : Colors.grey,
                                                            ),
                                                            onPressed: () async {
                                                                if (_currentUserId == null) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                        const SnackBar(content: Text('Please log in to like a post.')),
                                                                    );
                                                                    return;
                                                                }
                                                                try {
                                                                    // The toggleLike RPC in your service returns the new count (int).
                                                                    // We don't need to use the return value here, as we reload the stream.
                                                                    await _likeService.toggleLike(postId, _currentUserId!);
                                                                    
                                                                    // Reload the stream to fetch the updated count and user_liked status.
                                                                    setState(() {
                                                                        _postsStream = _getRealtimePosts();
                                                                    });
                                                                } catch (e) {
                                                                    debugPrint('Error toggling like: $e');
                                                                    if (context.mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                            const SnackBar(content: Text('Failed to update like status.')),
                                                                        );
                                                                    }
                                                                }
                                                            },
                                                        ),
                                                        Text('$likeCount likes'),
                                                    ],
                                                ),
                                            ),
                                        ],
                                    ),

                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}