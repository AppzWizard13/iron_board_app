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
import 'package:dio/dio.dart';

/// Service for handling Cashfree payment gateway integration
class PaymentService {
  final CFPaymentGatewayService cfPaymentGatewayService = CFPaymentGatewayService();

  static String get CLIENT_ID => dotenv.env['CASHFREE_APP_ID'] ?? '';
  static String get CLIENT_SECRET => dotenv.env['CASHFREE_SECRET_KEY'] ?? '';
  static const String CASHFREE_BASE_URL = "https://sandbox.cashfree.com";

  /// Creates a payment session with Cashfree
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

      print('📥 CASHFREE API RESPONSE: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        final paymentSessionId = responseData['payment_session_id'];
        final orderIdResponse = responseData['order_id'];

        final session = CFSessionBuilder()
            .setEnvironment(CFEnvironment.SANDBOX)
            .setOrderId(orderIdResponse)
            .setPaymentSessionId(paymentSessionId)
            .build();

        print('✅ Payment session created successfully');
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

  /// Starts the payment process
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

/// Service for communicating with Django backend API - Enhanced with 500 error debugging
class GymAPIService {
  static late final String BASE_URL = dotenv.env['API_URL']?.trim() ?? "https://your-django-app.com";
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Get auth token using your exact method
  static Future<String?> getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  /// Clear tokens when invalid
  static Future<void> clearTokens() async {
    await _storage.delete(key: 'auth_token_jwt');
    await _storage.delete(key: 'auth_token');
  }

  /// Get user profile using your exact format
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await getAuthToken();
    print("token:::::::::::::::::::::::::::: $token");
    
    if (token == null) {
      print("❌ No token available");
      return null;
    }

    try {
      final isJWT = token.split('.').length == 3;
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      
      print("🌐 Fetching profile from: $baseUrl/api/user/profile/");
      print("🔑 Token type: ${isJWT ? 'JWT Bearer' : 'DRF Token'}");
      
      final response = await dio.get(
        '$baseUrl/api/user/profile/',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        print("✅ Profile fetched successfully");
        return response.data;
      } else {
        print("❌ Profile fetch failed: ${response.statusCode}");
        if (response.statusCode == 401) {
          await clearTokens();
        }
        return null;
      }
    } catch (e) {
      print("💥 Profile fetch error: $e");
      if (e.toString().contains('401')) {
        await clearTokens();
      }
      return null;
    }
  }

  /// Enhanced initiate subscription payment with detailed 500 error logging
  static Future<Map<String, dynamic>?> initiateSubscriptionPayment({
    required String memberId,
    required int packageId,
  }) async {
    final token = await getAuthToken();
    print("🔐 Using token for payment initiation: ${token?.substring(0, 20)}...");
    
    if (token == null) {
      print("❌ No token available for payment");
      return null;
    }

    try {
      final isJWT = token.split('.').length == 3;
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      
      // Add detailed logging interceptor
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('🔍 DIO LOG: $obj'),
      ));
      
      print('🚀 Initiating subscription payment...');
      print('👤 Member ID: $memberId');
      print('📦 Package ID: $packageId');
      print('🔑 Auth type: ${isJWT ? 'JWT Bearer' : 'DRF Token'}');
      print('🌐 Full URL: $baseUrl/api/payments/initiate-subscription/');
      
      final requestData = {
        "member_id": memberId,
        "package_id": packageId,
      };
      
      print('📤 Request Data: ${json.encode(requestData)}');
      
      final response = await dio.post(
        '$baseUrl/api/payments/initiate-subscription/',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
          },
          responseType: ResponseType.json,
          // Don't throw error on 500, let us handle it
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      print('📥 Backend Response Status: ${response.statusCode}');
      print('📄 Backend Response Body: ${response.data}');

      if (response.statusCode == 201) {
        print('✅ Subscription initiated successfully');
        return response.data;
      } else if (response.statusCode == 401) {
        print('🚨 Token invalid/expired - clearing tokens');
        await clearTokens();
        throw Exception('🚨 Authentication failed: Token expired. Please login again.');
      } else if (response.statusCode == 500) {
        print('💥 SERVER ERROR (500): ${response.data}');
        // Extract detailed server error message
        String serverError = 'Unknown server error';
        if (response.data != null) {
          if (response.data is Map && response.data['detail'] != null) {
            serverError = response.data['detail'];
          } else if (response.data is Map && response.data['error'] != null) {
            serverError = response.data['error'];
          } else if (response.data is Map && response.data['message'] != null) {
            serverError = response.data['message'];
          } else {
            serverError = response.data.toString();
          }
        }
        throw Exception('🚨 Server Error (500): $serverError');
      } else {
        print('❌ Failed to initiate subscription: ${response.statusCode}');
        throw Exception('Backend error (${response.statusCode}): ${response.data}');
      }
    } catch (e) {
      print('💥 Subscription initiation error: $e');
      
      // Enhanced DioException handling for 500 errors
      if (e is DioException) {
        print('💥 DioException Details:');
        print('   Type: ${e.type}');
        print('   Message: ${e.message}');
        
        if (e.response != null) {
          print('   Status Code: ${e.response!.statusCode}');
          print('   Response Data: ${e.response!.data}');
          print('   Response Headers: ${e.response!.headers}');
          
          // Extract detailed server error for 500
          if (e.response!.statusCode == 500) {
            String detailedError = 'Server Internal Error';
            try {
              final errorData = e.response!.data;
              if (errorData is Map) {
                detailedError = errorData['detail'] ?? 
                               errorData['error'] ?? 
                               errorData['message'] ?? 
                               'Unknown server error';
              } else if (errorData is String) {
                detailedError = errorData;
              }
            } catch (parseError) {
              print('   Could not parse error response: $parseError');
            }
            
            throw Exception('🚨 Server Error: $detailedError\n📋 Member ID: $memberId | Package ID: $packageId');
          }
        }
      }
      
      if (e.toString().contains('401') || e.toString().contains('token')) {
        await clearTokens();
        throw Exception('🚨 Authentication failed: Please login again.');
      }
      
      throw Exception('Payment initiation failed: $e');
    }
  }

  /// Update payment status using your exact format with enhanced error handling
  static Future<Map<String, dynamic>?> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String transactionId,
    String paymentMethod = 'cashfree',
    Map<String, dynamic>? gatewayResponse,
  }) async {
    final token = await getAuthToken();
    
    if (token == null) {
      print("❌ No token available for payment update");
      return null;
    }

    try {
      final isJWT = token.split('.').length == 3;
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      
      print('🔄 Updating payment status: $paymentStatus');
      
      final response = await dio.post(
        '$baseUrl/api/payments/update-status/',
        data: {
          "order_id": orderId,
          "payment_status": paymentStatus,
          "transaction_id": transactionId,
          "payment_method": paymentMethod,
          "gateway_response": gatewayResponse ?? {},
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
          },
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      print('📥 Update Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Payment status updated successfully');
        return response.data;
      } else if (response.statusCode == 500) {
        print('💥 Payment update server error: ${response.data}');
        return null;
      } else {
        print('❌ Failed to update payment status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('💥 Payment update error: $e');
      if (e is DioException && e.response?.statusCode == 500) {
        print('💥 Payment update 500 error: ${e.response?.data}');
      }
      return null;
    }
  }
}

/// Complete Payment Flow using your exact token handling
class CompletePaymentFlow {
  final PaymentService _paymentService = PaymentService();

  /// Process complete subscription payment with proper user data
  Future<PaymentResult> processCompleteSubscriptionPayment({
    required String memberId,
    required int packageId,
    Function(PaymentResult)? onPaymentComplete,
  }) async {
    print('🚨 STARTING SECURE PAYMENT FLOW');
    print('👤 Member ID: $memberId');
    print('📦 Package ID: $packageId');

    try {
      // STEP 1: Backend subscription creation using your exact format
      print('\n📝 STEP 1: Creating backend subscription...');
      
      final subscriptionData = await GymAPIService.initiateSubscriptionPayment(
        memberId: memberId,
        packageId: packageId,
      );

      if (subscriptionData == null || subscriptionData['success'] != true) {
        throw Exception('❌ Backend subscription creation failed');
      }

      final orderData = subscriptionData['subscription_order'];
      final orderId = orderData['order_number'];
      
      print('✅ Step 1 completed - Backend order: $orderId');

      // STEP 2: Cashfree payment session
      print('\n💳 STEP 2: Creating Cashfree session...');
      
      final session = await _paymentService.createPaymentSession(
        orderId: orderId,
        amount: orderData['total'].toDouble(),
        customerName: orderData['customer_name'],
        customerEmail: orderData['customer_email'],
        customerPhone: orderData['customer_phone'],
      );

      if (session == null) {
        throw Exception('❌ Cashfree session creation failed');
      }

      print('✅ Step 2 completed - Cashfree session created');

      // STEP 3: Launch payment UI
      print('\n🚀 STEP 3: Launching payment UI...');
      PaymentResult? result;
      
      await _paymentService.startPayment(
        session,
        (paymentOrderId) async {
          print('\n🎉 PAYMENT SUCCESS');
          
          final updateResult = await GymAPIService.updatePaymentStatus(
            orderId: orderId,
            paymentStatus: 'SUCCESS',
            transactionId: paymentOrderId,
            gatewayResponse: {
              'cashfree_order_id': paymentOrderId,
              'payment_time': DateTime.now().toIso8601String(),
            },
          );
          
          result = PaymentResult(
            success: true,
            message: '🎉 Payment completed successfully!',
            orderId: orderId,
            transactionId: paymentOrderId,
            subscriptionData: updateResult?['subscription'],
          );
          
          onPaymentComplete?.call(result!);
        },
        (error, paymentOrderId) async {
          print('\n💔 PAYMENT FAILED: ${error.getMessage()}');
          
          await GymAPIService.updatePaymentStatus(
            orderId: orderId,
            paymentStatus: 'FAILED',
            transactionId: paymentOrderId ?? '',
            gatewayResponse: {
              'error_message': error.getMessage(),
            },
          );
          
          result = PaymentResult(
            success: false,
            message: '💔 Payment failed: ${error.getMessage() ?? 'Unknown error'}',
            orderId: orderId,
            transactionId: paymentOrderId,
          );
          
          onPaymentComplete?.call(result!);
        },
      );

      return result ?? PaymentResult(
        success: false,
        message: '⏳ Payment UI launched, awaiting completion...',
        orderId: orderId,
      );

    } catch (e, stackTrace) {
      print('💥 CRITICAL PAYMENT ERROR: $e');
      print('💥 Stack trace: $stackTrace');
      
      final errorResult = PaymentResult(
        success: false,
        message: e.toString(),
      );
      
      onPaymentComplete?.call(errorResult);
      return errorResult;
    }
  }
}

/// Payment result data class
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

  String? get packageName => subscriptionData?['package_name'];
  String? get subscriptionExpiryDate => subscriptionData?['expiry_date'];
  bool get isSubscriptionActive => subscriptionData?['active'] == true;

  @override
  String toString() {
    return 'PaymentResult{success: $success, message: $message, orderId: $orderId}';
  }
}

/// Payment manager with your exact token handling
class PaymentManager {
  final CompletePaymentFlow _paymentFlow = CompletePaymentFlow();

  /// Start subscription payment using actual user data
  Future<void> startSubscriptionPayment({
    required String memberId,
    required int packageId,
    required Function(PaymentResult) onComplete,
    Function(String)? onStatusUpdate,
  }) async {
    print('🎯 PAYMENT MANAGER: Starting with proper user data');
    print('👤 Member ID: $memberId');
    print('📦 Package ID: $packageId');

    try {
      // Validate configuration
      if (PaymentService.CLIENT_ID.isEmpty || PaymentService.CLIENT_SECRET.isEmpty) {
        onComplete(PaymentResult(success: false, message: 'Cashfree configuration missing'));
        return;
      }

      if (GymAPIService.BASE_URL == "https://your-django-app.com") {
        onComplete(PaymentResult(success: false, message: 'Backend API URL not configured'));
        return;
      }

      onStatusUpdate?.call('🚀 Starting secure payment flow...');
      
      await _paymentFlow.processCompleteSubscriptionPayment(
        memberId: memberId,
        packageId: packageId,
        onPaymentComplete: (result) {
          print('🎯 Payment completed: ${result.success ? "SUCCESS" : "FAILED"}');
          onComplete(result);
        },
      );
    } catch (e) {
      print('💥 Payment Manager Error: $e');
      onComplete(PaymentResult(
        success: false,
        message: e.toString(),
      ));
    }
  }
}

/// Payment Screen Widget - Enhanced with better user ID handling
class PaymentScreen extends StatefulWidget {
  final double amount;
  final String itemName;
  final int packageId;
  
  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.itemName,
    required this.packageId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentManager _paymentManager = PaymentManager();
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _error;
  String _status = 'Loading user profile...';

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  /// Fetch user profile using GymAPIService
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
      _userProfile = null;
    });

    try {
      final profileData = await GymAPIService.getUserProfile();
      
      if (profileData != null) {
        setState(() {
          _userProfile = profileData;
          _isLoadingProfile = false;
          _status = 'Profile loaded - Ready for payment';
        });
        
        print('🎯 User Profile Loaded:');
        print('   👤 Name: ${profileData['name']}');
        print('   📧 Email: ${profileData['email']}');
        print('   🆔 ID: ${profileData['id']}');
      } else {
        setState(() {
          _error = "Failed to load user profile. Please login again.";
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error loading profile: $e";
        _isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Payment'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user profile...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _userProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Payment'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(_error ?? 'Unable to load profile'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserProfile,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug Info Card - Shows which user ID will be used
            Card(
              color: Colors.yellow.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔍 Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('User ID: ${_userProfile!['id'] ?? 'NOT FOUND'}'),
                    Text('Member ID: ${_userProfile!['member_id'] ?? 'NOT FOUND'}'),
                    Text('Package ID: ${widget.packageId}'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // User Profile Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User: ${_userProfile!['name'] ?? 'Unknown'}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Email: ${_userProfile!['email'] ?? ''}'),
                    Text('Phone: ${_userProfile!['phone'] ?? ''}'),
                    if (_userProfile!['gym_name']?.isNotEmpty == true)
                      Text('Gym: ${_userProfile!['gym_name']}'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Summary', style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.itemName),
                        Text('₹${widget.amount.toStringAsFixed(2)}'),
                      ],
                    ),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${widget.amount.toStringAsFixed(2)}', 
                             style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Status Card
            Card(
              color: _status.contains('error') || _status.contains('failed') 
                  ? Colors.red.shade50 
                  : Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            
            Spacer(),
            
            // Payment Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('🚀 Start Secure Payment', style: TextStyle(color: Colors.white)),
              ),
            ),
            
            SizedBox(height: 10),
            
            Text(
              '🔒 Enhanced logging: Will show detailed 500 error information',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Initiate payment with actual user ID and enhanced error logging
  Future<void> _initiatePayment() async {
    if (_userProfile == null) {
      _showMessage("User profile not available", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Starting payment flow...';
    });

    try {
      // Try multiple user ID fields in order of preference
      final actualUserId = _userProfile!['id']?.toString() ?? 
                          _userProfile!['member_id']?.toString() ?? 
                          _userProfile!['user_id']?.toString() ?? '';
      
      if (actualUserId.isEmpty) {
        throw Exception('❌ No user ID found in profile. Available keys: ${_userProfile!.keys.toList()}');
      }

      print('🎯 Starting payment with ACTUAL user ID: $actualUserId');
      print('👤 User Name: ${_userProfile!['name']}');
      print('📦 Package ID: ${widget.packageId}');
      print('💰 Amount: ₹${widget.amount}');
      print('🔍 Profile keys available: ${_userProfile!.keys.toList()}');

      await _paymentManager.startSubscriptionPayment(
        memberId: actualUserId, // Using actual user ID from profile
        packageId: widget.packageId,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        },
        onComplete: (result) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _status = result.message;
            });

            if (result.success) {
              _showSuccessDialog(result);
            } else {
              if (result.message.contains('Authentication') || 
                  result.message.contains('login')) {
                _showAuthErrorDialog(result.message);
              } else {
                _showErrorDialog(result.message);
              }
            }
          }
        },
      );
    } catch (e) {
      print("💥 Payment error: $e");
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _status = 'Payment failed: $e';
        });
      }
      
      if (e.toString().contains('Authentication') || e.toString().contains('token')) {
        _showAuthErrorDialog("Authentication error: $e");
      } else {
        _showMessage("Payment error: $e", isError: true);
      }
    }
  }

  void _showSuccessDialog(PaymentResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉 Your payment was successful!'),
            SizedBox(height: 10),
            Text('Order ID: ${result.orderId}'),
            if (result.transactionId != null)
              Text('Transaction ID: ${result.transactionId}'),
            if (result.subscriptionExpiryDate != null)
              Text('Subscription expires: ${result.subscriptionExpiryDate}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAuthErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Authentication Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            SizedBox(height: 10),
            Text('Please login again to continue.',
                 style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Login Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Payment Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          if (!_isLoading)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initiatePayment();
              },
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
