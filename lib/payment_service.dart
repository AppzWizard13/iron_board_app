import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentcomponents/cfpaymentcomponent.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for handling Cashfree payment gateway integration
class PaymentService {
  final CFPaymentGatewayService cfPaymentGatewayService = CFPaymentGatewayService();

  static String get CLIENT_ID => dotenv.env['CASHFREE_APP_ID'] ?? '';
  static String get CLIENT_SECRET => dotenv.env['CASHFREE_SECRET_KEY'] ?? '';
  static const String CASHFREE_BASE_URL = "https://sandbox.cashfree.com";

  /// Creates a payment session with Cashfree using backend order data
  Future<CFSession?> createPaymentSession({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      print('🌍 CASHFREE API REQUEST STARTED');
      print('📍 URL: $CASHFREE_BASE_URL/pg/orders');
      print('📦 Order ID: $orderId');
      print('💰 Amount: ₹$amount');
      print('👤 Customer: $customerName ($customerEmail)');
      
      final headers = {
        'Content-Type': 'application/json',
        'x-client-id': CLIENT_ID,
        'x-client-secret': CLIENT_SECRET,
        'x-api-version': '2022-09-01',
        'x-request-id': 'flutter_app_${DateTime.now().millisecondsSinceEpoch}'
      };

      print('🔑 Headers: ${headers.keys.join(', ')}');

      final body = {
        "order_amount": amount,
        "order_id": orderId,
        "order_currency": "INR",
        "customer_details": {
          "customer_id": "customer_${DateTime.now().millisecondsSinceEpoch}",
          "customer_name": customerName,
          "customer_email": customerEmail,
          "customer_phone": customerPhone
        },
        "order_meta": {
          "return_url": "https://test.cashfree.com/pgappsdemos/return.php?order_id=$orderId"
        }
      };

      print('📤 Request Body: ${json.encode(body)}');

      final request = http.Request('POST', Uri.parse('$CASHFREE_BASE_URL/pg/orders'));
      request.headers.addAll(headers);
      request.body = json.encode(body);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 CASHFREE API RESPONSE');
      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);

        final paymentSessionId = responseData['payment_session_id'];
        final orderIdResponse = responseData['order_id'];

        print('✅ Payment session created successfully');
        print('🔐 Session ID: $paymentSessionId');
        print('🏷️ Order ID: $orderIdResponse');

        final session = CFSessionBuilder()
            .setEnvironment(CFEnvironment.SANDBOX)
            .setOrderId(orderIdResponse)
            .setPaymentSessionId(paymentSessionId)
            .build();

        return session;
      } else {
        print('❌ Failed to create payment session: ${response.statusCode}');
        print('📄 Error Response: $responseBody');
        return null;
      }
    } catch (e) {
      print('💥 CASHFREE API ERROR: $e');
      return null;
    }
  }

  /// Starts the payment process with custom UI theme
  Future<void> startPayment(
    CFSession session, 
    Function(String) onSuccess, 
    Function(CFErrorResponse, String) onError  
  ) async {
    try {
      print('🚀 Starting Cashfree payment UI...');
      
      final List<CFPaymentModes> paymentModes = <CFPaymentModes>[];

      final paymentComponent = CFPaymentComponentBuilder()
          .setComponents(paymentModes)
          .build();

      final cfTheme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor("#FF6B35")
          .setNavigationBarTextColor("#FFFFFF")
          .setPrimaryFont("Menlo")
          .setSecondaryFont("Futura")
          .build();

      final cfDropCheckoutPayment = CFDropCheckoutPaymentBuilder()
          .setSession(session)
          .setPaymentComponent(paymentComponent)
          .setTheme(cfTheme)
          .build();

      cfPaymentGatewayService.setCallback(onSuccess, onError);
      await cfPaymentGatewayService.doPayment(cfDropCheckoutPayment);
      
      print('💳 Payment UI launched successfully');
    } catch (e) {
      print('💥 Payment UI launch error: $e');
    }
  }
}

/// Service for communicating with Django backend API
class GymAPIService {
  static late final String BASE_URL = dotenv.env['API_URL']?.trim() ?? "https://your-django-app.com";
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Get authentication token from secure storage
  static Future<String?> getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  /// Logs request details for debugging
  void _logRequest(String method, String url, Map<String, String> headers, String body) {
    print('🌐 BACKEND API REQUEST STARTED');
    print('📍 URL: $url');
    print('🔄 Method: $method');
    print('🔑 Headers: ${headers.entries.map((e) => '${e.key}: ${e.key.contains('Authorization') ? 'Bearer ***' : e.value}').join(', ')}');
    if (body.isNotEmpty) {
      print('📤 Request Body: $body');
    }
  }

  /// Logs response details for debugging
  void _logResponse(String url, int statusCode, String responseBody) {
    print('📥 BACKEND API RESPONSE');
    print('📍 URL: $url');
    print('📊 Status Code: $statusCode');
    print('📄 Response Body: $responseBody');
    if (statusCode >= 200 && statusCode < 300) {
      print('✅ Request successful');
    } else {
      print('❌ Request failed');
    }
  }

  /// Initiates subscription payment by creating database entries - STEP 2 in flow
  Future<Map<String, dynamic>?> initiateSubscriptionPayment({
    required String memberId,
    required int packageId,
    required String authToken,
  }) async {
    try {
      final url = '$BASE_URL/api/payments/initiate-subscription/';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

      final body = {
        "member_id": memberId,
        "package_id": packageId,
      };

      final bodyJson = json.encode(body);

      print('🚀 Initiating subscription payment...');
      print('👤 Member ID: $memberId');
      print('📦 Package ID: $packageId');
      
      _logRequest('POST', url, headers, bodyJson);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: bodyJson,
      );

      _logResponse(url, response.statusCode, response.body);

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ Subscription initiated successfully');
        print('📋 Order created: ${responseData['subscription_order']?['order_number']}');
        return responseData;
      } else {
        print('❌ Failed to initiate subscription');
        _parseErrorResponse(response.body);
        return null;
      }
    } catch (e) {
      print('💥 Error initiating subscription: $e');
      return null;
    }
  }

  /// Parse and display error response details
  void _parseErrorResponse(String responseBody) {
    try {
      final errorData = json.decode(responseBody);
      print('🚫 Error Details:');
      print('   Message: ${errorData['message'] ?? 'Unknown error'}');
      if (errorData['errors'] != null) {
        print('   Errors: ${errorData['errors']}');
      }
    } catch (e) {
      print('🚫 Raw Error Response: $responseBody');
    }
  }
}

/// Service for updating payment status after payment completion - STEP 8 in flow
class PaymentUpdateService {
  static late final String BASE_URL = dotenv.env['API_URL']?.trim() ?? "https://your-django-app.com";

  /// Updates payment status in Django backend
  Future<Map<String, dynamic>?> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String transactionId,
    required String authToken,
    String paymentMethod = 'cashfree',
    Map<String, dynamic>? gatewayResponse,
  }) async {
    try {
      final url = '$BASE_URL/api/payments/update-status/';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

      final body = {
        "order_id": orderId,
        "payment_status": paymentStatus,
        "transaction_id": transactionId,
        "payment_method": paymentMethod,
        "gateway_response": gatewayResponse ?? {},
      };

      final bodyJson = json.encode(body);

      print('🔄 Updating payment status...');
      print('📋 Order ID: $orderId');
      print('📊 Status: $paymentStatus');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: bodyJson,
      );

      print('📥 Payment Update Response: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Payment status updated successfully');
        return responseData;
      } else {
        print('❌ Failed to update payment status');
        return null;
      }
    } catch (e) {
      print('💥 Error updating payment status: $e');
      return null;
    }
  }
}

/// Complete Payment Flow Manager - Orchestrates the entire 10-step flow
class CompletePaymentFlow {
  final GymAPIService _gymAPI = GymAPIService();
  final PaymentService _paymentService = PaymentService();
  final PaymentUpdateService _paymentUpdateService = PaymentUpdateService();

  /// Processes the complete subscription payment flow (Steps 2-10)
  Future<PaymentResult> processCompleteSubscriptionPayment({
    required String memberId,
    required int packageId,
    required String authToken,
    Function(PaymentResult)? onPaymentComplete,
  }) async {
    print('🚨 COMPLETE PAYMENT FLOW STARTED - 10 STEP PROCESS');
    print('👤 Member ID: $memberId');
    print('📦 Package ID: $packageId');

    try {
      // STEP 2: Flutter calls YOUR backend API: /api/payments/initiate-subscription/
      print('\n📝 STEP 2: Calling backend to initiate subscription payment...');
      
      final subscriptionData = await _gymAPI.initiateSubscriptionPayment(
        memberId: memberId,
        packageId: packageId,
        authToken: authToken,
      );

      if (subscriptionData == null || !subscriptionData['success']) {
        throw Exception('❌ STEP 2 FAILED: Backend subscription initiation failed');
      }

      // STEP 3: Backend validates & creates order/payment record ✅ (handled by backend)
      // STEP 4: Backend returns order details (ID, amount, customer info) ✅
      final orderData = subscriptionData['subscription_order'];
      final orderId = orderData['order_number'];
      
      print('✅ STEPS 2-4 COMPLETED: Backend order created successfully');
      print('   📋 Order ID: $orderId');
      print('   💰 Amount: ₹${orderData['total']}');
      print('   👤 Customer: ${orderData['customer_name']}');

      // STEP 5: Flutter calls Cashfree SDK with backend data
      print('\n💳 STEP 5: Creating Cashfree payment session with backend data...');
      
      final session = await _paymentService.createPaymentSession(
        orderId: orderId,
        amount: orderData['total'].toDouble(),
        customerName: orderData['customer_name'],
        customerEmail: orderData['customer_email'],
        customerPhone: orderData['customer_phone'],
      );

      if (session == null) {
        throw Exception('❌ STEP 5 FAILED: Cashfree session creation failed');
      }

      print('✅ STEP 5 COMPLETED: Cashfree payment session created');

      // STEP 6: User completes payment in Cashfree UI
      print('\n🚀 STEP 6: Launching Cashfree UI for user payment...');
      PaymentResult? result;
      
      await _paymentService.startPayment(
        session,
        (paymentOrderId) async {
          // STEP 7: Flutter receives payment result (SUCCESS)
          print('\n🎉 STEP 7: Payment SUCCESS received from Cashfree');
          print('🔢 Transaction ID: $paymentOrderId');
          
          try {
            // STEP 8: Flutter calls YOUR backend: /api/payments/update-status/
            print('\n🔄 STEP 8: Updating backend with payment SUCCESS...');
            
            final updateResult = await _paymentUpdateService.updatePaymentStatus(
              orderId: orderId,
              paymentStatus: 'SUCCESS',
              transactionId: paymentOrderId,
              authToken: authToken,
              gatewayResponse: {
                'cashfree_order_id': paymentOrderId,
                'payment_time': DateTime.now().toIso8601String(),
                'payment_method': 'cashfree',
                'status': 'completed',
              },
            );
            
            if (updateResult != null && updateResult['success'] == true) {
              // STEP 9: Backend updates payment status & activates subscription ✅
              result = PaymentResult(
                success: true,
                message: '🎉 Payment completed successfully! Your subscription is now active.',
                orderId: orderId,
                transactionId: paymentOrderId,
                subscriptionData: updateResult['subscription'],
              );
              print('✅ STEPS 8-9 COMPLETED: Backend updated, subscription activated');
            } else {
              result = PaymentResult(
                success: false,
                message: '⚠️ Payment completed but backend update failed',
                orderId: orderId,
                transactionId: paymentOrderId,
              );
              print('❌ STEP 8-9 FAILED: Backend update unsuccessful');
            }
          } catch (e) {
            print('💥 ERROR in STEPS 8-9: $e');
            result = PaymentResult(
              success: false,
              message: '⚠️ Payment completed but backend update error: ${e.toString()}',
              orderId: orderId,
              transactionId: paymentOrderId,
            );
          }
          
          // STEP 10: Show final result to user
          print('\n🏁 STEP 10: Showing final result to user');
          print('🏁 COMPLETE FLOW STATUS: ${result!.success ? "✅ SUCCESS" : "❌ PARTIAL SUCCESS"}');
          onPaymentComplete?.call(result!);
        },
        (error, paymentOrderId) async {
          // STEP 7: Flutter receives payment result (FAILURE)
          print('\n💔 STEP 7: Payment FAILURE received from Cashfree');
          print('🚫 Error: ${error.getMessage()}');
          
          try {
            // STEP 8: Flutter calls YOUR backend: /api/payments/update-status/
            print('\n🔄 STEP 8: Updating backend with payment FAILURE...');
            
            await _paymentUpdateService.updatePaymentStatus(
              orderId: orderId,
              paymentStatus: 'FAILED',
              transactionId: paymentOrderId ?? '',
              authToken: authToken,
              gatewayResponse: {
                'error_message': error.getMessage(),
                'error_code': error.getType(),
                'error_time': DateTime.now().toIso8601String(),
                'payment_method': 'cashfree',
                'status': 'failed',
              },
            );
            print('✅ STEP 8: Backend updated with failure status');
          } catch (e) {
            print('💥 ERROR in STEP 8: $e');
          }
          
          result = PaymentResult(
            success: false,
            message: '💔 Payment failed: ${error.getMessage() ?? 'Unknown payment error'}',
            orderId: orderId,
            transactionId: paymentOrderId,
          );
          
          // STEP 10: Show final result to user
          print('\n🏁 STEP 10: Showing failure result to user');
          print('🏁 COMPLETE FLOW STATUS: ❌ FAILED');
          onPaymentComplete?.call(result!);
        },
      );

      print('✅ STEP 6 COMPLETED: Payment UI launched, awaiting user interaction');

      // Return pending result (callbacks will update this)
      return result ?? PaymentResult(
        success: false,
        message: '⏳ Payment UI launched, awaiting user completion...',
        orderId: orderId,
      );

    } catch (e, stackTrace) {
      print('💥 CRITICAL ERROR IN PAYMENT FLOW: $e');
      print('💥 Stack trace: $stackTrace');
      
      final errorResult = PaymentResult(
        success: false,
        message: '💥 Payment flow error: ${e.toString()}',
      );
      onPaymentComplete?.call(errorResult);
      return errorResult;
    }
  }
}

/// Result class for payment operations
class PaymentResult {
  final bool success;
  final String message;
  final String? orderId;
  final String? transactionId;
  final Map<String, dynamic>? subscriptionData;
  final DateTime timestamp;

  PaymentResult({
    required this.success,
    required this.message,
    this.orderId,
    this.transactionId,
    this.subscriptionData,
  }) : timestamp = DateTime.now();

  /// Get subscription package name
  String? get packageName => subscriptionData?['package_name'];
  
  /// Get subscription expiry date
  String? get subscriptionExpiryDate => subscriptionData?['expiry_date'];
  
  /// Check if subscription is active
  bool get isSubscriptionActive => subscriptionData?['active'] == true;

  @override
  String toString() {
    return 'PaymentResult{success: $success, message: $message, orderId: $orderId, transactionId: $transactionId, timestamp: $timestamp}';
  }
}

/// Payment Manager - Easy to use wrapper for the complete flow
class PaymentManager {
  final CompletePaymentFlow _paymentFlow = CompletePaymentFlow();

  /// Starts the complete 10-step payment flow
  Future<void> startSubscriptionPayment({
    required String memberId,
    required int packageId,
    required String authToken,
    required Function(PaymentResult) onComplete,
    Function(String)? onStatusUpdate,
  }) async {
    print('🎯 PAYMENT MANAGER: Starting 10-step payment flow');
    
    onStatusUpdate?.call('🔧 Validating configuration...');
    
    // Validate configuration
    if (PaymentService.CLIENT_ID.isEmpty || PaymentService.CLIENT_SECRET.isEmpty) {
      onComplete(PaymentResult(success: false, message: 'Cashfree configuration missing'));
      return;
    }

    if (GymAPIService.BASE_URL == "https://your-django-app.com") {
      onComplete(PaymentResult(success: false, message: 'Backend API URL not configured'));
      return;
    }

    onStatusUpdate?.call('🚀 Step 1: Starting payment process...');
    
    await _paymentFlow.processCompleteSubscriptionPayment(
      memberId: memberId,
      packageId: packageId,
      authToken: authToken,
      onPaymentComplete: (result) {
        print('🎯 PAYMENT MANAGER: Final result received - ${result.success ? "SUCCESS" : "FAILED"}');
        onComplete(result);
      },
    );
  }
}
