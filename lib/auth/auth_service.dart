import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart'; 

class AuthService {
  static const _region = 'us-east-1';
  static const _clientId = 'a06q3f5i77ejv8mlo75mr2v6n';
  static final _baseUrl = "https://cognito-idp.${_region}.amazonaws.com";

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
      },
    ),
  );

  /// Sign up a new user
Future<bool> signUpUser({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String role,
}) async {
final payload = {
  "ClientId": _clientId,
  "Username": email,
  "Password": password,
  "UserAttributes": [
    {"Name": "email", "Value": email},
    {"Name": "given_name", "Value": firstName},
    {"Name": "family_name", "Value": lastName},
    {"Name": "custom:role", "Value": role},  
  ]
};


    try {
      debugPrint('SignUp Payload: ${jsonEncode(payload)}');

      final response = await _dio.post(
        '',
        options: Options(
          headers: {
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp',
          },
        ),
        data: jsonEncode(payload),
      );

      debugPrint('SignUp Response: ${response.data}');

      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('SignUp Error: ${e.response?.data}');
      throw Exception('${e.response?.data?["message"] ?? "Registration failed"}');
    }
  }

  /// Confirm a newly registered user
  Future<bool> confirmUser(String email, String code) async {
    final payload = {
      "ClientId": _clientId,
      "Username": email,
      "ConfirmationCode": code,
    };

    try {
      debugPrint('Confirm Payload: ${jsonEncode(payload)}');

      final response = await _dio.post(
        '',
        options: Options(
          headers: {
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp',
          },
        ),
        data: jsonEncode(payload),
      );

      debugPrint('Confirm Response: ${response.data}');

      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Confirm Error: ${e.response?.data}');
      throw Exception('${e.response?.data?["message"] ?? "Confirmation failed"}');
    }
  }

  /// Sign in user
 

Future<Map<String, String>?> signInUser({
  required String email,
  required String password,
}) async {
  final url = Uri.parse(_baseUrl);
  final headers = {
    'Content-Type': 'application/x-amz-json-1.1',
    'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
  };

  final body = jsonEncode({
    'AuthFlow': 'USER_PASSWORD_AUTH',
    'ClientId': _clientId,
    'AuthParameters': {
      'USERNAME': email,
      'PASSWORD': password,
    }
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final idToken = data['AuthenticationResult']['IdToken'] as String;

    final decoded = JwtDecoder.decode(idToken);
    final role = decoded['custom:role'] ?? 'Trainee';

    return {'token': idToken, 'role': role};
  } else {
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Login failed');
  }
}


  /// Initiate password reset
  Future<void> forgotPassword({required String email}) async {
    final payload = {
      "ClientId": _clientId,
      "Username": email,
    };

    try {
      debugPrint('ForgotPassword Payload: ${jsonEncode(payload)}');

      final response = await _dio.post(
        '',
        options: Options(
          headers: {
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.ForgotPassword',
          },
        ),
        data: jsonEncode(payload),
      );

      debugPrint('ForgotPassword Response: ${response.data}');

      if (response.statusCode != 200) {
        throw Exception('Failed to send reset code');
      }
    } on DioException catch (e) {
      debugPrint('ForgotPassword Error: ${e.response?.data}');
      throw Exception('${e.response?.data?["message"] ?? "Failed to send reset code"}');
    }
  }

  /// Confirm password reset
  Future<void> confirmForgotPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final payload = {
      "ClientId": _clientId,
      "Username": email,
      "ConfirmationCode": code,
      "Password": newPassword,
    };

    try {
      debugPrint('ConfirmForgotPassword Payload: ${jsonEncode(payload)}');

      final response = await _dio.post(
        '',
        options: Options(
          headers: {
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmForgotPassword',
          },
        ),
        data: jsonEncode(payload),
      );

      debugPrint('ConfirmForgotPassword Response: ${response.data}');

      if (response.statusCode != 200) {
        throw Exception('Failed to reset password');
      }
    } on DioException catch (e) {
      debugPrint('ConfirmForgotPassword Error: ${e.response?.data}');
      throw Exception('${e.response?.data?["message"] ?? "Failed to reset password"}');
    }
  }
}
