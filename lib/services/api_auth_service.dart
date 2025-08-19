import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for managing authentication headers in API requests
class ApiAuthService {
  static final ApiAuthService _instance = ApiAuthService._internal();
  factory ApiAuthService() => _instance;
  ApiAuthService._internal();

  /// Get authentication headers for API requests
  Map<String, String> getAuthHeaders() {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'BabbleOn-Mobile/1.0',
    };
    
    // Add JWT token if user is authenticated
    if (session?.accessToken != null) {
      headers['Authorization'] = 'Bearer ${session!.accessToken}';
      debugPrint('API Auth: Adding JWT token to request');
    } else {
      debugPrint('API Auth: No JWT token available - user may not be authenticated');
    }
    
    return headers;
  }
  
  /// Get authentication headers for multipart requests
  Map<String, String> getMultipartAuthHeaders() {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    final headers = <String, String>{
      'User-Agent': 'BabbleOn-Mobile/1.0',
    };
    
    // Add JWT token if user is authenticated
    if (session?.accessToken != null) {
      headers['Authorization'] = 'Bearer ${session!.accessToken}';
      debugPrint('API Auth: Adding JWT token to multipart request');
    } else {
      debugPrint('API Auth: No JWT token available for multipart request');
    }
    
    return headers;
  }
  
  /// Add authentication headers to an existing HTTP request
  void addAuthToRequest(http.MultipartRequest request) {
    final authHeaders = getMultipartAuthHeaders();
    request.headers.addAll(authHeaders);
  }
  
  /// Add authentication headers to a regular HTTP request
  void addAuthToHttpRequest(http.Request request) {
    final authHeaders = getAuthHeaders();
    request.headers.addAll(authHeaders);
  }
  
  /// Check if user is currently authenticated
  bool get isAuthenticated {
    final supabase = Supabase.instance.client;
    return supabase.auth.currentSession?.accessToken != null;
  }
  
  /// Get current user ID if authenticated
  String? get currentUserId {
    final supabase = Supabase.instance.client;
    return supabase.auth.currentUser?.id;
  }
  
  /// Handle authentication errors from API responses
  bool handleAuthError(int statusCode) {
    if (statusCode == 401) {
      debugPrint('API Auth: Received 401 Unauthorized - token may be expired');
      // In a production app, you might want to refresh the token or redirect to login
      return true;
    }
    return false;
  }
}

/// Global instance for easy access
final apiAuthService = ApiAuthService();