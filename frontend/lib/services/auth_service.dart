import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql/client.dart';

class AuthService {
  final String _backendUrl;
  final http.Client _client;
  late final GraphQLClient _gqlClient;
  String? _token;
  Map<String, dynamic>? _cachedSession;

  Map<String, dynamic>? get cachedSession => _cachedSession;

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal()
      : _backendUrl = const String.fromEnvironment('BACKEND_HTTP', defaultValue: 'http://localhost:8080'),
        _client = kIsWeb ? (BrowserClient()..withCredentials = true) : http.Client() {
    _loadToken();
    _initGraphQL();
  }

  void _initGraphQL() {
    final HttpLink httpLink = HttpLink(
      '$_backendUrl/graphql',
      httpClient: _client,
    );

    final AuthLink authLink = AuthLink(
      getToken: () async => _token != null ? 'Bearer $_token' : null,
    );

    _gqlClient = GraphQLClient(
      link: authLink.concat(httpLink),
      cache: GraphQLCache(),
    );
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Error loading token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<void> _clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      debugPrint('Error clearing token: $e');
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Get current user session via GraphQL
  Future<Map<String, dynamic>?> getSession() async {
    try {
      const String getSessionQuery = r'''
        query GetMe {
          me {
            user {
              id
              name
              email
              emailVerified
              image
              role
              createdAt
              updatedAt
            }
            session {
              id
              userId
              expiresAt
              token
              ipAddress
              userAgent
              createdAt
              updatedAt
              activeOrganizationId
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(getSessionQuery),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error getting session: ${result.exception.toString()}');
        return null;
      }

      final data = result.data?['me'];
      if (data != null && data['session'] != null) {
        final sessionToken = data['session']['token'];
        if (sessionToken != null) {
          await _saveToken(sessionToken);
        }
        _cachedSession = {
          'user': data['user'],
          'session': data['session'],
        };
        return _cachedSession;
      }
      _cachedSession = null;
      return null;
    } catch (e) {
      debugPrint('Error getting session: $e');
      _cachedSession = null;
      return null;
    }
  }

  // Send Magic Link (Auth flow, remains REST)
  Future<bool> sendMagicLink(String email, String callbackUrl) async {
    try {
      final response = await _client.post(
        Uri.parse('$_backendUrl/api/auth/sign-in/magic-link'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'callbackURL': callbackUrl,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending magic link: $e');
      return false;
    }
  }

  // Get Google OAuth URL (Auth flow, remains REST)
  String getGoogleLoginUrl(String callbackUrl) {
    return '$_backendUrl/api/auth/login/social?provider=google&callbackURL=${Uri.encodeComponent(callbackUrl)}';
  }

  // Sign out (Auth flow, remains REST to clear cookies/session)
  Future<bool> signOut() async {
    _cachedSession = null;
    try {
      await _client.post(
        Uri.parse('$_backendUrl/api/auth/sign-out'),
        headers: _getHeaders(),
        body: jsonEncode({}),
      );
      await _clearToken();
      return true;
    } catch (e) {
      debugPrint('Error signing out: $e');
      await _clearToken(); // Clear token even if network request fails
      return false;
    }
  }

  // List user organizations via GraphQL
  Future<List<dynamic>> listOrganizations() async {
    try {
      const String listOrgsQuery = r'''
        query ListOrgs {
          organizations {
            id
            organizationId
            userId
            role
            createdAt
            organization {
              id
              name
              slug
              logo
              createdAt
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(listOrgsQuery),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error listing organizations: ${result.exception.toString()}');
        return [];
      }

      return result.data?['organizations'] ?? [];
    } catch (e) {
      debugPrint('Error listing organizations: $e');
      return [];
    }
  }

  // Create an organization via GraphQL
  Future<Map<String, dynamic>?> createOrganization(String name, String slug) async {
    try {
      const String createOrgMutation = r'''
        mutation CreateOrg($name: String!, $slug: String!) {
          createOrganization(name: $name, slug: $slug) {
            id
            name
            slug
            logo
            createdAt
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(createOrgMutation),
        variables: {
          'name': name,
          'slug': slug,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error creating organization: ${result.exception.toString()}');
        return null;
      }

      final org = result.data?['createOrganization'];
      return org as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error creating organization: $e');
      return null;
    }
  }

  // Fetch Admin Stats via GraphQL
  Future<Map<String, dynamic>?> getAdminStats() async {
    try {
      const String adminStatsQuery = r'''
        query GetAdminStats {
          adminStats {
            totalUsers
            activeSessions
            totalOrganizations
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(adminStatsQuery),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error getting admin stats: ${result.exception.toString()}');
        return null;
      }

      return result.data?['adminStats'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting admin stats: $e');
      return null;
    }
  }

  // List movies via GraphQL
  Future<List<dynamic>> listMovies() async {
    try {
      const String listMoviesQuery = r'''
        query ListMovies {
          movies {
            id
            title
            genre
            director
            releaseYear
            description
            bannerUrl
            userId
            createdAt
            updatedAt
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(listMoviesQuery),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error listing movies: ${result.exception.toString()}');
        return [];
      }

      return result.data?['movies'] ?? [];
    } catch (e) {
      debugPrint('Error listing movies: $e');
      return [];
    }
  }

  // Create a movie via GraphQL
  Future<Map<String, dynamic>?> createMovie({
    required String title,
    required String genre,
    required String director,
    required int releaseYear,
    String? description,
    String? bannerUrl,
  }) async {
    try {
      const String createMovieMutation = r'''
        mutation CreateMovie($title: String!, $genre: String!, $director: String!, $releaseYear: Int!, $description: String, $bannerUrl: String) {
          createMovie(title: $title, genre: $genre, director: $director, releaseYear: $releaseYear, description: $description, bannerUrl: $bannerUrl) {
            id
            title
            genre
            director
            releaseYear
            description
            bannerUrl
            userId
            createdAt
            updatedAt
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(createMovieMutation),
        variables: {
          'title': title,
          'genre': genre,
          'director': director,
          'releaseYear': releaseYear,
          'description': description,
          'bannerUrl': bannerUrl,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error creating movie: ${result.exception.toString()}');
        return null;
      }

      return result.data?['createMovie'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error creating movie: $e');
      return null;
    }
  }

  // Update a movie via GraphQL
  Future<Map<String, dynamic>?> updateMovie({
    required String id,
    String? title,
    String? genre,
    String? director,
    int? releaseYear,
    String? description,
    String? bannerUrl,
  }) async {
    try {
      const String updateMovieMutation = r'''
        mutation UpdateMovie($id: ID!, $title: String, $genre: String, $director: String, $releaseYear: Int, $description: String, $bannerUrl: String) {
          updateMovie(id: $id, title: $title, genre: $genre, director: $director, releaseYear: $releaseYear, description: $description, bannerUrl: $bannerUrl) {
            id
            title
            genre
            director
            releaseYear
            description
            bannerUrl
            userId
            createdAt
            updatedAt
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(updateMovieMutation),
        variables: {
          'id': id,
          'title': title,
          'genre': genre,
          'director': director,
          'releaseYear': releaseYear,
          'description': description,
          'bannerUrl': bannerUrl,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error updating movie: ${result.exception.toString()}');
        return null;
      }

      return result.data?['updateMovie'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error updating movie: $e');
      return null;
    }
  }

  // Delete a movie via GraphQL
  Future<bool> deleteMovie(String id) async {
    try {
      const String deleteMovieMutation = r'''
        mutation DeleteMovie($id: ID!) {
          deleteMovie(id: $id)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(deleteMovieMutation),
        variables: {
          'id': id,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error deleting movie: ${result.exception.toString()}');
        return false;
      }

      return result.data?['deleteMovie'] == true;
    } catch (e) {
      debugPrint('Error deleting movie: $e');
      return false;
    }
  }

  // Get presigned upload URL via GraphQL
  Future<Map<String, dynamic>?> getPresignedUploadUrl(String fileName, String contentType) async {
    try {
      const String getPresignedUrlQuery = r'''
        query GetPresignedUploadUrl($fileName: String!, $contentType: String!) {
          presignedUploadUrl(fileName: $fileName, contentType: $contentType) {
            uploadUrl
            publicUrl
            key
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(getPresignedUrlQuery),
        variables: {
          'fileName': fileName,
          'contentType': contentType,
        },
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error getting presigned URL: ${result.exception.toString()}');
        return null;
      }

      return result.data?['presignedUploadUrl'];
    } catch (e) {
      debugPrint('Error getting presigned URL: $e');
      return null;
    }
  }

  // Upload file bytes directly to S3/R2 presigned URL
  Future<bool> uploadFile(String uploadUrl, List<int> fileBytes, String contentType) async {
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        body: fileBytes,
        headers: {
          'Content-Type': contentType,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error uploading file to S3/R2: $e');
      return false;
    }
  }

  // Update profile image via GraphQL
  Future<bool> updateProfileImage(String imageUrl) async {
    try {
      const String updateProfileImageMutation = r'''
        mutation UpdateProfileImage($image: String!) {
          updateProfileImage(image: $image) {
            id
            image
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(updateProfileImageMutation),
        variables: {
          'image': imageUrl,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error updating profile image: ${result.exception.toString()}');
        return false;
      }

      return result.data?['updateProfileImage'] != null;
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      return false;
    }
  }

  // Set the active organization
  Future<Map<String, dynamic>?> setActiveOrganization(String organizationId) async {
    try {
      const String setActiveMutation = r'''
        mutation SetActiveOrg($organizationId: ID!) {
          setActiveOrganization(organizationId: $organizationId) {
            id
            userId
            expiresAt
            token
            activeOrganizationId
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(setActiveMutation),
        variables: {
          'organizationId': organizationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error setting active organization: ${result.exception.toString()}');
        return null;
      }

      final sessionData = result.data?['setActiveOrganization'];
      if (sessionData != null && _cachedSession != null) {
        _cachedSession!['session'] = sessionData;
      }
      return sessionData as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error setting active organization: $e');
      return null;
    }
  }

  // List members of active organization
  Future<List<dynamic>> listActiveOrganizationMembers(String organizationId) async {
    try {
      const String query = r'''
        query GetActiveOrgMembers($organizationId: ID!) {
          activeOrganizationMembers(organizationId: $organizationId) {
            id
            organizationId
            userId
            role
            createdAt
            user {
              id
              name
              email
              image
              role
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        variables: {'organizationId': organizationId},
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error listing members: ${result.exception.toString()}');
        return [];
      }

      return result.data?['activeOrganizationMembers'] ?? [];
    } catch (e) {
      debugPrint('Error listing members: $e');
      return [];
    }
  }

  // List invitations of active organization
  Future<List<dynamic>> listActiveOrganizationInvitations(String organizationId) async {
    try {
      const String query = r'''
        query GetActiveOrgInvitations($organizationId: ID!) {
          activeOrganizationInvitations(organizationId: $organizationId) {
            id
            organizationId
            email
            role
            status
            expiresAt
            createdAt
            inviter {
              id
              name
              email
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        variables: {'organizationId': organizationId},
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error listing invitations: ${result.exception.toString()}');
        return [];
      }

      return result.data?['activeOrganizationInvitations'] ?? [];
    } catch (e) {
      debugPrint('Error listing invitations: $e');
      return [];
    }
  }

  // List pending invitations for the logged-in user
  Future<List<dynamic>> listMyPendingInvitations() async {
    try {
      const String query = r'''
        query GetMyPendingInvitations {
          myPendingInvitations {
            id
            organizationId
            email
            role
            status
            expiresAt
            createdAt
            inviter {
              id
              name
              email
            }
            organization {
              id
              name
              slug
            }
          }
        }
      ''';

      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await _gqlClient.query(options);

      if (result.hasException) {
        debugPrint('GraphQL Error listing my invitations: ${result.exception.toString()}');
        return [];
      }

      return result.data?['myPendingInvitations'] ?? [];
    } catch (e) {
      debugPrint('Error listing my invitations: $e');
      return [];
    }
  }

  // Invite a member
  Future<Map<String, dynamic>?> inviteMember({
    required String email,
    required String role,
    required String organizationId,
  }) async {
    try {
      const String inviteMutation = r'''
        mutation Invite($email: String!, $role: String!, $organizationId: ID!) {
          inviteMember(email: $email, role: $role, organizationId: $organizationId) {
            id
            organizationId
            email
            role
            status
            expiresAt
            createdAt
          }
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(inviteMutation),
        variables: {
          'email': email,
          'role': role,
          'organizationId': organizationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error inviting member: ${result.exception.toString()}');
        final errors = result.exception?.graphqlErrors;
        if (errors != null && errors.isNotEmpty) {
          throw Exception(errors.first.message);
        }
        throw Exception('Failed to invite member');
      }

      return result.data?['inviteMember'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error inviting member: $e');
      rethrow;
    }
  }

  // Cancel invitation
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      const String cancelMutation = r'''
        mutation Cancel($invitationId: ID!) {
          cancelInvitation(invitationId: $invitationId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(cancelMutation),
        variables: {
          'invitationId': invitationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error cancelling invitation: ${result.exception.toString()}');
        return false;
      }

      return result.data?['cancelInvitation'] == true;
    } catch (e) {
      debugPrint('Error cancelling invitation: $e');
      return false;
    }
  }

  // Accept invitation
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      const String acceptMutation = r'''
        mutation Accept($invitationId: ID!) {
          acceptInvitation(invitationId: $invitationId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(acceptMutation),
        variables: {
          'invitationId': invitationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error accepting invitation: ${result.exception.toString()}');
        return false;
      }

      return result.data?['acceptInvitation'] == true;
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      return false;
    }
  }

  // Reject invitation
  Future<bool> rejectInvitation(String invitationId) async {
    try {
      const String rejectMutation = r'''
        mutation Reject($invitationId: ID!) {
          rejectInvitation(invitationId: $invitationId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(rejectMutation),
        variables: {
          'invitationId': invitationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error rejecting invitation: ${result.exception.toString()}');
        return false;
      }

      return result.data?['rejectInvitation'] == true;
    } catch (e) {
      debugPrint('Error rejecting invitation: $e');
      return false;
    }
  }

  // Remove member
  Future<bool> removeMember(String memberId, String organizationId) async {
    try {
      const String removeMutation = r'''
        mutation Remove($memberId: ID!, $organizationId: ID!) {
          removeMember(memberId: $memberId, organizationId: $organizationId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(removeMutation),
        variables: {
          'memberId': memberId,
          'organizationId': organizationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error removing member: ${result.exception.toString()}');
        return false;
      }

      return result.data?['removeMember'] == true;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  // Update member role
  Future<bool> updateMemberRole(String memberId, String role, String organizationId) async {
    try {
      const String updateMutation = r'''
        mutation UpdateRole($memberId: ID!, $role: String!, $organizationId: ID!) {
          updateMemberRole(memberId: $memberId, role: $role, organizationId: $organizationId)
        }
      ''';

      final MutationOptions options = MutationOptions(
        document: gql(updateMutation),
        variables: {
          'memberId': memberId,
          'role': role,
          'organizationId': organizationId,
        },
      );

      final QueryResult result = await _gqlClient.mutate(options);

      if (result.hasException) {
        debugPrint('GraphQL Error updating member role: ${result.exception.toString()}');
        return false;
      }

      return result.data?['updateMemberRole'] == true;
    } catch (e) {
      debugPrint('Error updating member role: $e');
      return false;
    }
  }
}
