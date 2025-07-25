import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class MtnMomoService {
  final String subscriptionKey = '8df0f2fc72c84361978de2c50a7d0a3d'; // Replace with your actual key
  final String apiUser = '51a06b51-7b0e-45be-b321-ac37e90ea807'; // Replace with your actual API user
  final String apiKey = '7e4cc124b84441c4a3535a0cf756ab7d'; // Replace with your actual API key
  final String baseUrl = 'https://sandbox.momodeveloper.mtn.com';
  
  /// Step 1: Create API User (Only needed once during setup)
  Future<void> createApiUser() async {
    final referenceId = const Uuid().v4();
    final url = Uri.parse('$baseUrl/v1_0/apiuser');
    
    final response = await http.post(
      url,
      headers: {
        'X-Reference-Id': referenceId,
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'providerCallbackHost': 'string'
      }),
    );
    
    if (response.statusCode == 201) {
      print('API User created successfully with ID: $referenceId');
      // Store this referenceId as your apiUser
    } else {
      throw Exception('Failed to create API user: ${response.body}');
    }
  }
  
  /// Step 2: Create API Key (Only needed once during setup)
  Future<void> createApiKey() async {
    final url = Uri.parse('$baseUrl/v1_0/apiuser/$apiUser/apikey');
    
    final response = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('API Key created: ${data['apiKey']}');
      // Store this as your apiKey
    } else {
      throw Exception('Failed to create API key: ${response.body}');
    }
  }

  /// Step 3: Get Access Token
  Future<String> getAccessToken() async {
    final url = Uri.parse('$baseUrl/collection/token/');
    final credentials = base64Encode(utf8.encode('$apiUser:$apiKey'));
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Basic $credentials',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to get access token: ${response.statusCode} - ${response.body}');
    }
  }

  /// Step 4: Request To Pay
  Future<String> requestToPay({
    required String phoneNumber,
    required String amount,
    String currency = 'UGX',
    String? externalId,
    String? payerMessage,
    String? payeeNote,
  }) async {
    try {
      final accessToken = await getAccessToken();
      final referenceId = const Uuid().v4();
      final url = Uri.parse('$baseUrl/collection/v1_0/requesttopay');
      
      // Format phone number (remove leading 0 and add country code)
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        formattedPhone = '256${phoneNumber.substring(1)}';
      }
      
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'X-Reference-Id': referenceId,
        'X-Target-Environment': 'sandbox',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'application/json',
      };
      
      final body = jsonEncode({
        'amount': amount,
        'currency': currency,
        'externalId': externalId ?? const Uuid().v4(),
        'payer': {
          'partyIdType': 'MSISDN',
          'partyId': formattedPhone,
        },
        'payerMessage': payerMessage ?? 'Payment request',
        'payeeNote': payeeNote ?? 'Thank you for your payment',
      });
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 202) {
        print('✅ Payment request sent successfully. Reference ID: $referenceId');
        return referenceId;
      } else {
        throw Exception('Payment request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }

  /// Step 5: Check Payment Status
  Future<Map<String, dynamic>> getPaymentStatus(String referenceId) async {
    try {
      final accessToken = await getAccessToken();
      final url = Uri.parse('$baseUrl/collection/v1_0/requesttopay/$referenceId');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get payment status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking payment status: $e');
    }
  }

  /// Helper method to poll payment status until completion
  Future<Map<String, dynamic>> waitForPaymentCompletion(
    String referenceId, {
    int maxAttempts = 30,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final status = await getPaymentStatus(referenceId);
        final paymentStatus = status['status'];
        
        if (paymentStatus == 'SUCCESSFUL' || paymentStatus == 'FAILED') {
          return status;
        }
        
        // Wait before next attempt
        await Future.delayed(delay);
      } catch (e) {
        if (i == maxAttempts - 1) {
          throw Exception('Payment status check failed after $maxAttempts attempts: $e');
        }
      }
    }
    
    throw Exception('Payment status check timed out after $maxAttempts attempts');
  }
}