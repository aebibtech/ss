import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/session_guard.dart';
import '../services/auth_service.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<dynamic> _movies = [];
  bool _loadingMovies = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _fetchMovies();
  }

  Future<void> _fetchMovies() async {
    setState(() => _loadingMovies = true);
    final list = await _authService.listMovies();
    if (mounted) {
      setState(() {
        _movies = list;
        _loadingMovies = false;
      });
    }
  }

  void _showMovieDialog(BuildContext context, [Map<String, dynamic>? movieItem]) {
    final isEditing = movieItem != null;
    final titleController = TextEditingController(text: movieItem?['title'] ?? '');
    final genreController = TextEditingController(text: movieItem?['genre'] ?? '');
    final directorController = TextEditingController(text: movieItem?['director'] ?? '');
    final yearController = TextEditingController(text: movieItem?['releaseYear']?.toString() ?? '');
    final descController = TextEditingController(text: movieItem?['description'] ?? '');
    final formKey = GlobalKey<FormState>();
    String? bannerUrl = movieItem?['bannerUrl'];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Movie' : 'Add Movie', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.movie_creation_outlined)),
                      validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: genreController,
                      decoration: const InputDecoration(labelText: 'Genre', prefixIcon: Icon(Icons.theater_comedy_outlined)),
                      validator: (v) => v == null || v.isEmpty ? 'Genre is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: directorController,
                      decoration: const InputDecoration(labelText: 'Director', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Director is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: yearController,
                      decoration: const InputDecoration(labelText: 'Release Year', prefixIcon: Icon(Icons.calendar_today_outlined)),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Year is required';
                        if (int.tryParse(v) == null) return 'Enter a valid year';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Image Upload Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Movie Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                bannerUrl != null ? 'Image uploaded' : 'No banner image uploaded',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isUploading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent),
                          )
                        else if (bannerUrl != null)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  bannerUrl!,
                                  width: 60,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 40,
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.broken_image_outlined, size: 16, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      bannerUrl = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
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
                                    final presignedData = await _authService.getPresignedUploadUrl(file.name, contentType);
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
                                    final uploadSuccess = await _authService.uploadFile(uploadUrl, fileBytes, contentType);
                                    if (!uploadSuccess) {
                                      setDialogState(() {
                                        isUploading = false;
                                      });
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        const SnackBar(content: Text('Failed to upload file.')),
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      isUploading = false;
                                      bannerUrl = publicUrl;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isUploading = false;
                                    });
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(content: Text('Upload error: $e')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.upload_outlined, size: 14),
                          label: Text(bannerUrl != null ? 'Change' : 'Upload'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.of(dialogContext).pop();

                        final title = titleController.text.trim();
                        final genre = genreController.text.trim();
                        final director = directorController.text.trim();
                        final releaseYear = int.parse(yearController.text.trim());
                        final description = descController.text.trim();

                        Map<String, dynamic>? result;
                        if (isEditing) {
                          result = await _authService.updateMovie(
                            id: movieItem['id'],
                            title: title,
                            genre: genre,
                            director: director,
                            releaseYear: releaseYear,
                            description: description.isNotEmpty ? description : null,
                            bannerUrl: bannerUrl,
                          );
                        } else {
                          result = await _authService.createMovie(
                            title: title,
                            genre: genre,
                            director: director,
                            releaseYear: releaseYear,
                            description: description.isNotEmpty ? description : null,
                            bannerUrl: bannerUrl,
                          );
                        }

                        if (result != null) {
                          _fetchMovies();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Movie updated!' : 'Movie added!')),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to save movie.')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteMovie(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Movie'),
        content: const Text('Are you sure you want to delete this movie?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _authService.deleteMovie(id);
      if (success) {
        _fetchMovies();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movie deleted.')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete movie.')),
          );
        }
      }
    }
  }

  Widget _buildMovieCard(BuildContext context, Map<String, dynamic> item) {
    final hasBanner = item['bannerUrl'] != null && item['bannerUrl'].toString().isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBanner)
            Image.network(
              item['bannerUrl'],
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.movie_outlined, color: Colors.white70, size: 40),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Untitled',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showMovieDialog(context, item),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteMovie(context, item['id']),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['genre'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 11, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Released: ${item['releaseYear']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Director: ${item['director']}',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item['description'],
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesTab(BuildContext context, bool isMobile) {
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Movies Library',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchMovies,
              tooltip: 'Refresh Library',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showMovieDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Movie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );

    if (_loadingMovies) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
        ],
      );
    }

    if (_movies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_filter_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No movies in your library.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Click "Add Movie" to start building your collection.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final content = isMobile
        ? ListView.builder(
            itemCount: _movies.length,
            itemBuilder: (context, index) {
              final item = _movies[index];
              return _buildMovieCard(context, item);
            },
          )
        : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _movies.length,
            itemBuilder: (context, index) {
              final item = _movies[index];
              return _buildMovieCard(context, item);
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 20),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      builder: (context, session, authService) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return DashboardLayout(
          selectedTab: 1,
          authService: authService,
          session: session,
          child: _buildMoviesTab(context, isMobile),
        );
      },
    );
  }
}
