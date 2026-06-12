import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';

class DashboardLayout extends StatelessWidget {
  final Widget child;
  final int selectedTab;
  final AuthService authService;
  final Map<String, dynamic> session;

  const DashboardLayout({
    super.key,
    required this.child,
    required this.selectedTab,
    required this.authService,
    required this.session,
  });

  Future<void> _signOut(BuildContext context) async {
    final success = await authService.signOut();
    if (success && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _onTabSelected(BuildContext context, int index) {
    if (index == selectedTab) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed('/counter');
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed('/movies');
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed('/organizations');
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed('/admin');
        break;
    }
  }

  void _showUserProfileDialog(BuildContext context) {
    final user = session['user'];
    final userRole = user['role'] ?? 'user';
    final name = user['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    
    bool isUploading = false;
    String? currentImageUrl = user['image'] as String?;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: currentImageUrl != null ? NetworkImage(currentImageUrl!) : null,
                        backgroundColor: Colors.deepPurpleAccent,
                        child: currentImageUrl == null && !isUploading
                            ? Text(initial, style: const TextStyle(fontSize: 28))
                            : null,
                      ),
                      if (isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurpleAccent,
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: isUploading ? null : () async {
                              try {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.image,
                                  withData: true,
                                );
                                if (result == null || result.files.isEmpty) return;
                                
                                final file = result.files.first;
                                final fileBytes = file.bytes;
                                if (fileBytes == null) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Could not read file data.')),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isUploading = true;
                                });

                                final extension = file.extension?.toLowerCase() ?? 'png';
                                final contentType = 'image/$extension';

                                // 1. Get presigned URL
                                final presignedData = await authService.getPresignedUploadUrl(file.name, contentType);
                                if (presignedData == null) {
                                  setDialogState(() {
                                    isUploading = false;
                                  });
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Failed to generate upload URL.')),
                                  );
                                  return;
                                }

                                final uploadUrl = presignedData['uploadUrl'] as String;
                                final publicUrl = presignedData['publicUrl'] as String;

                                // 2. Upload to S3/R2 directly
                                final uploadSuccess = await authService.uploadFile(uploadUrl, fileBytes, contentType);
                                if (!uploadSuccess) {
                                  setDialogState(() {
                                    isUploading = false;
                                  });
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Failed to upload file.')),
                                  );
                                  return;
                                }

                                // 3. Update database
                                final updateSuccess = await authService.updateProfileImage(publicUrl);
                                if (!updateSuccess) {
                                  setDialogState(() {
                                    isUploading = false;
                                  });
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Failed to update profile picture.')),
                                  );
                                  return;
                                }

                                // Update local states
                                setDialogState(() {
                                  isUploading = false;
                                  currentImageUrl = publicUrl;
                                });

                                // Force reload the screen to fetch updated session from parent session checker
                                Navigator.of(dialogContext).pop();
                                Navigator.of(context).pushReplacementNamed(
                                  selectedTab == 0 ? '/counter' :
                                  selectedTab == 1 ? '/movies' :
                                  selectedTab == 2 ? '/organizations' : '/admin'
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile picture updated successfully!')),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  isUploading = false;
                                });
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Upload error: $e')),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(name.isNotEmpty ? name : (user['email'] as String? ?? 'User'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user['email'] as String? ?? '', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: userRole == 'admin' ? Colors.red.shade900 : Colors.deepPurpleAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      userRole.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: userRole == 'admin' ? Colors.white : Colors.deepPurpleAccent,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _signOut(context);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = session['user'];
    final userRole = user['role'] ?? 'user';
    final isAdmin = userRole == 'admin';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New App', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showUserProfileDialog(context),
                child: Builder(
                  builder: (context) {
                    final name = user['name'] as String? ?? '';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                    final displayName = name.isNotEmpty ? name : (user['email'] as String? ?? 'User');
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: user['image'] != null ? NetworkImage(user['image']) : null,
                          backgroundColor: Colors.deepPurpleAccent,
                          child: user['image'] == null ? Text(initial) : null,
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(user['email'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ),
              if (isAdmin && !isMobile) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
              if (!isMobile) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _signOut(context),
                  tooltip: 'Sign Out',
                ),
              ],
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: isMobile
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black12,
              child: child,
            )
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedTab,
                  onDestinationSelected: (int index) => _onTabSelected(context, index),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.add),
                      selectedIcon: Icon(Icons.add_box),
                      label: Text('Counter'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie),
                      label: Text('Movies'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.group_outlined),
                      selectedIcon: Icon(Icons.group),
                      label: Text('Organizations'),
                    ),
                    if (isAdmin)
                      const NavigationRailDestination(
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        selectedIcon: Icon(Icons.admin_panel_settings),
                        label: Text('Admin Panel'),
                      ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.black12,
                    child: child,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (int index) => _onTabSelected(context, index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.add),
                  selectedIcon: Icon(Icons.add_box),
                  label: 'Counter',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: 'Movies',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'Organizations',
                ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings),
                    label: 'Admin Panel',
                  ),
              ],
            )
          : null,
    );
  }
}
