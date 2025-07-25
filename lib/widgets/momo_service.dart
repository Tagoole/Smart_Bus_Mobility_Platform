import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class MtnMomoService {
  // Backend API base URL
  final String backendBaseUrl = 'https://api-abp277afba-uc.a.run.app';
  
  /// Health check to verify backend is running
  Future<bool> checkBackendHealth() async {
    try {
      final url = Uri.parse('$backendBaseUrl/health');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Backend health check: ${data['status']}');
        return data['status'] == 'OK';
      }
      return false;
    } catch (e) {
      print('❌ Backend health check failed: $e');
      return false;
    }
  }

  /// Request To Pay using backend API
  Future<String> requestToPay({
    required String phoneNumber,
    required String amount,
    String currency = 'UGX',
    String? externalId,
    String? payerMessage,
    String? payeeNote,
  }) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/requesttopay');
      
      // Format phone number (remove leading 0 and add country code for Uganda)
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        formattedPhone = '256${phoneNumber.substring(1)}';
      }
      
      final headers = {
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
      
      print('📱 Sending payment request for $amount $currency to $formattedPhone');
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Payment request sent successfully. Reference ID: ${data['referenceId']}');
          return data['referenceId'];
        } else {
          throw Exception('Payment request failed: ${data['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Payment request failed: ${response.statusCode} - ${errorData['message']}');
      }
    } catch (e) {
      print('❌ Error processing payment: $e');
      throw Exception('Error processing payment: $e');
    }
  }

  /// Check Payment Status using backend API
  Future<Map<String, dynamic>> getPaymentStatus(String referenceId) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/transaction/$referenceId');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return responseData['data'];
        } else {
          throw Exception('Failed to get payment status: ${responseData['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to get payment status: ${response.statusCode} - ${errorData['message']}');
      }
    } catch (e) {
      print('❌ Error checking payment status: $e');
      throw Exception('Error checking payment status: $e');
    }
  }

  /// Get Account Balance using backend API
  Future<Map<String, dynamic>> getAccountBalance() async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/balance');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('💰 Account balance retrieved successfully');
          return responseData['data'];
        } else {
          throw Exception('Failed to get balance: ${responseData['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to get balance: ${response.statusCode} - ${errorData['message']}');
      }
    } catch (e) {
      print('❌ Error getting account balance: $e');
      throw Exception('Error getting account balance: $e');
    }
  }

  /// Get Account Holder Info using backend API
  Future<Map<String, dynamic>> getAccountHolderInfo({
    required String accountHolderId,
    String accountHolderIdType = 'MSISDN',
  }) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/accountholder');
      
      final headers = {
        'Content-Type': 'application/json',
      };
      
      final body = jsonEncode({
        'accountHolderIdType': accountHolderIdType,
        'accountHolderId': accountHolderId,
      });
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('👤 Account holder info retrieved successfully');
          return responseData['data'];
        } else {
          throw Exception('Failed to get account holder info: ${responseData['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to get account holder info: ${response.statusCode} - ${errorData['message']}');
      }
    } catch (e) {
      print('❌ Error getting account holder info: $e');
      throw Exception('Error getting account holder info: $e');
    }
  }

  /// Validate Account Holder using backend API
  Future<bool> validateAccountHolder({
    required String accountHolderId,
    String accountHolderIdType = 'MSISDN',
  }) async {
    try {
      final url = Uri.parse('$backendBaseUrl/api/validate-account');
      
      final headers = {
        'Content-Type': 'application/json',
      };
      
      final body = jsonEncode({
        'accountHolderIdType': accountHolderIdType,
        'accountHolderId': accountHolderId,
      });
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final isActive = responseData['isActive'] ?? false;
          print('✅ Account validation: ${isActive ? 'Active' : 'Inactive'}');
          return isActive;
        } else {
          throw Exception('Failed to validate account: ${responseData['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to validate account: ${response.statusCode} - ${errorData['message']}');
      }
    } catch (e) {
      print('❌ Error validating account: $e');
      throw Exception('Error validating account: $e');
    }
  }

  /// Helper method to poll payment status until completion
  Future<Map<String, dynamic>> waitForPaymentCompletion(
    String referenceId, {
    int maxAttempts = 30,
    Duration delay = const Duration(seconds: 2),
  }) async {
    print('⏳ Waiting for payment completion...');
    
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final status = await getPaymentStatus(referenceId);
        final paymentStatus = status['status'];
        
        print('🔄 Payment status (attempt ${i + 1}): $paymentStatus');
        
        if (paymentStatus == 'SUCCESSFUL') {
          print('✅ Payment completed successfully!');
          return status;
        } else if (paymentStatus == 'FAILED') {
          print('❌ Payment failed!');
          return status;
        }
        
        // Wait before next attempt
        await Future.delayed(delay);
      } catch (e) {
        print('⚠️ Status check attempt ${i + 1} failed: $e');
        if (i == maxAttempts - 1) {
          throw Exception('Payment status check failed after $maxAttempts attempts: $e');
        }
      }
    }
    
    throw Exception('Payment status check timed out after $maxAttempts attempts');
  }

  /// Complete payment flow with validation and status checking
  Future<Map<String, dynamic>> processPayment({
    required String phoneNumber,
    required String amount,
    String currency = 'UGX',
    String? externalId,
    String? payerMessage,
    String? payeeNote,
    bool waitForCompletion = false,
  }) async {
    try {
      // Step 1: Check backend health
      final isHealthy = await checkBackendHealth();
      if (!isHealthy) {
        throw Exception('Backend service is not available');
      }

      // Step 2: Validate phone number format
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        formattedPhone = '256${phoneNumber.substring(1)}';
      }

      // Step 3: Validate account holder (optional)
      try {
        final isValidAccount = await validateAccountHolder(
          accountHolderId: formattedPhone,
        );
        print('Account validation: ${isValidAccount ? 'Valid' : 'Invalid'}');
      } catch (e) {
        print('⚠️ Account validation failed (continuing anyway): $e');
      }

      // Step 4: Request payment
      final referenceId = await requestToPay(
        phoneNumber: phoneNumber,
        amount: amount,
        currency: currency,
        externalId: externalId,
        payerMessage: payerMessage,
        payeeNote: payeeNote,
      );

      // Step 5: Wait for completion if requested
      if (waitForCompletion) {
        return await waitForPaymentCompletion(referenceId);
      } else {
        // Return initial status
        return {
          'referenceId': referenceId,
          'status': 'PENDING',
          'message': 'Payment request sent successfully'
        };
      }
    } catch (e) {
      print('❌ Payment processing failed: $e');
      rethrow;
    }
  }
}