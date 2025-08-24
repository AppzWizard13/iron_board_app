import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

final storage = FlutterSecureStorage();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🟢 ============ BACKGROUND MESSAGE HANDLER START ============');
  print('🟢 Initializing Firebase in background handler...');
  
  await Firebase.initializeApp();
  
  print('🟢 Firebase initialized successfully');
  print('🟢 Background message received: ${message.messageId}');
  print('🟢 Background message title: ${message.notification?.title}');
  print('🟢 Background message body: ${message.notification?.body}');
  print('🟢 Background message data: ${message.data}');
  
  // Show notification for background messages
  print('🟢 Calling _showNotificationFromBackground...');
  await _showNotificationFromBackground(message);
  print('🟢 ============ BACKGROUND MESSAGE HANDLER END ============');
}

// Background notification display function
Future<void> _showNotificationFromBackground(RemoteMessage message) async {
  print('🔵 _showNotificationFromBackground started');
  
  try {
    print('🔵 Initializing local notifications plugin for background...');
    
    // Initialize local notifications plugin for background handler
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('🔵 Background local notifications initialized');

    print('🔵 Creating AndroidNotificationDetails for background...');
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      autoCancel: true,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      ticker: 'Iron Board Background Alert',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String title = message.notification?.title ?? 'Iron Board Background Alert';
    String body = message.notification?.body ?? 'You have a new background notification';
    
    print('🔵 About to show background notification with ID: $notificationId');
    print('🔵 Title: $title');
    print('🔵 Body: $body');

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );

    print('✅ Background notification displayed successfully with ID: $notificationId');
  } catch (e) {
    print('❌ Error displaying background notification: $e');
    print('❌ Stack trace: ${StackTrace.current}');
  }
}

Future<void> main() async {
  print('🚀 ============ MAIN FUNCTION START ============');
  
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 WidgetsFlutterBinding initialized');
  
  await dotenv.load(fileName: ".env");
  print('🚀 Environment variables loaded');
  
  await Firebase.initializeApp();
  print('🚀 Firebase initialized');

  // Initialize Firebase Analytics to remove warnings
  print('🚀 Initializing Firebase Analytics...');
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  print('🚀 Firebase Analytics enabled');
  
  // Set background message handler
  print('🚀 Setting background message handler...');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('🚀 Background message handler set');

  // Initialize FCM service
  print('🚀 Initializing FCM Service...');
  await FCMService.initialize();
  print('🚀 FCM Service initialized');

  print('🚀 Starting Flutter app...');
  runApp(const MyApp());
  print('🚀 ============ MAIN FUNCTION END ============');
}

// Enhanced FCM Service Class
class FCMService {
  static FirebaseMessaging? _messaging;
  static String? _fcmToken;
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    print('🔧 ============ FCMService INITIALIZE START ============');
    
    _messaging = FirebaseMessaging.instance;
    print('🔧 FirebaseMessaging instance obtained');

    // Initialize local notifications FIRST
    print('🔧 Calling _initializeLocalNotifications...');
    await _initializeLocalNotifications();
    print('🔧 Local notifications initialized');

    // Request permission
    print('🔧 Requesting notification permissions...');
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    print('🔧 Permission request completed');
    print('🔧 Authorization status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');

      // Clear any old token and get fresh one
      print('🔧 Deleting old FCM token...');
      await _messaging!.deleteToken();
      print('🔧 Old token deleted');
      
      // Get fresh token
      print('🔧 Getting fresh FCM token...');
      _fcmToken = await _messaging!.getToken();
      print('🎯 Fresh FCM Token: $_fcmToken');

      // Log FCM token event to Analytics
      print('🔧 Logging FCM token event to Analytics...');
      await analytics.logEvent(
        name: 'fcm_token_obtained',
        parameters: {
          'token_length': _fcmToken?.length ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      print('🔧 Analytics event logged');

      // Handle foreground messages - CRITICAL FOR DISPLAY
      print('🔧 Setting up foreground message listener...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔴 ============ FOREGROUND MESSAGE RECEIVED ============');
        print('🔴 Message ID: ${message.messageId}');
        print('🔴 Message title: ${message.notification?.title}');
        print('🔴 Message body: ${message.notification?.body}');
        print('🔴 Message data: ${message.data}');
        print('🔴 Has notification: ${message.notification != null}');
        print('🔴 Notification timestamp: ${DateTime.now()}');
        
        // Log foreground message event
        print('🔴 Logging foreground message event...');
        analytics.logEvent(
          name: 'notification_received_foreground',
          parameters: {
            'message_id': message.messageId ?? 'unknown',
            'has_notification': message.notification != null,
          },
        );
        
        // Show local notification for foreground messages
        print('🔴 Calling _showLocalNotification...');
        _showLocalNotification(message);
        print('🔴 ============ FOREGROUND MESSAGE PROCESSING END ============');
      });
      print('🔧 Foreground message listener set up');

      // Handle message when app is opened from notification
      print('🔧 Setting up onMessageOpenedApp listener...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🟡 ============ APP OPENED FROM NOTIFICATION ============');
        print('🟡 Message ID: ${message.messageId}');
        
        // Log notification interaction event
        analytics.logEvent(
          name: 'notification_opened',
          parameters: {
            'message_id': message.messageId ?? 'unknown',
            'from_background': true,
          },
        );
        print('🟡 ============ APP OPENED PROCESSING END ============');
      });
      print('🔧 onMessageOpenedApp listener set up');

      // Handle initial message (when app is launched from notification)
      print('🔧 Checking for initial message...');
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print('🟠 ============ APP LAUNCHED FROM NOTIFICATION ============');
          print('🟠 Message ID: ${message.messageId}');
          
          // Log app launch from notification event
          analytics.logEvent(
            name: 'notification_opened',
            parameters: {
              'message_id': message.messageId ?? 'unknown',
              'from_terminated': true,
            },
          );
          print('🟠 ============ APP LAUNCHED PROCESSING END ============');
        } else {
          print('🔧 No initial message found');
        }
      });

      // Listen for token refresh
      print('🔧 Setting up token refresh listener...');
      FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
        print('🔄 ============ TOKEN REFRESH TRIGGERED ============');
        _fcmToken = fcmToken;
        print('🔄 New FCM Token: $fcmToken');
        
        // Log token refresh event
        analytics.logEvent(name: 'fcm_token_refreshed');
        
        // Update token on backend if user is logged in
        String? authToken = await storage.read(key: 'auth_token_jwt') ?? 
                           await storage.read(key: 'auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          print('🔄 Sending refreshed token to backend...');
          await _sendTokenToBackend(fcmToken, authToken);
        } else {
          print('🔄 No auth token found, not sending to backend');
        }
        print('🔄 ============ TOKEN REFRESH END ============');
      }).onError((err) {
        print('❌ Error in token refresh listener: $err');
      });
      print('🔧 Token refresh listener set up');

    } else {
      print('❌ User declined or has not accepted notification permission');
      print('❌ Authorization status: ${settings.authorizationStatus}');
      
      // Log permission denied event
      analytics.logEvent(
        name: 'notification_permission_denied',
        parameters: {
          'authorization_status': settings.authorizationStatus.toString(),
        },
      );
    }
    
    print('🔧 ============ FCMService INITIALIZE END ============');
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    print('🔵 ============ LOCAL NOTIFICATIONS INIT START ============');
    
    print('🔵 Creating initialization settings...');
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    print('🔵 Initializing flutter_local_notifications plugin...');
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print('🔔 ============ NOTIFICATION TAPPED ============');
        print('🔔 Notification ID: ${details.id}');
        print('🔔 Payload: ${details.payload}');
        
        // Log notification tap event
        analytics.logEvent(
          name: 'local_notification_tapped',
          parameters: {
            'notification_id': details.id ?? 0,
            'payload_length': details.payload?.length ?? 0,
          },
        );
        print('🔔 ============ NOTIFICATION TAP PROCESSING END ============');
      },
    );
    print('🔵 Plugin initialized successfully');

    // Create notification channel for Android
    print('🔵 Creating Android notification channel...');
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      print('🔵 Creating notification channel...');
      await androidImplementation.createNotificationChannel(channel);
      print('✅ Notification channel created successfully');
    } else {
      print('❌ Android implementation not found');
    }
    
    print('🔵 ============ LOCAL NOTIFICATIONS INIT END ============');
  }

  // Show local notification - CRITICAL FOR FOREGROUND DISPLAY
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    print('🔔 ============ SHOW LOCAL NOTIFICATION START ============');
    print('🔔 Message ID: ${message.messageId}');
    print('🔔 Notification title: ${message.notification?.title}');
    print('🔔 Notification body: ${message.notification?.body}');
    print('🔔 Message data: ${message.data}');
    
    try {
      print('🔔 Creating AndroidNotificationDetails...');
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
        visibility: NotificationVisibility.public,
        ticker: 'Iron Board Alert',
      );
      print('🔔 AndroidNotificationDetails created');

      print('🔔 Creating DarwinNotificationDetails...');
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );
      print('🔔 DarwinNotificationDetails created');

      print('🔔 Creating NotificationDetails...');
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      print('🔔 NotificationDetails created');

      int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String title = message.notification?.title ?? 'Iron Board Alert';
      String body = message.notification?.body ?? 'You have a new notification';
      
      print('🔔 Prepared notification:');
      print('🔔   ID: $notificationId');
      print('🔔   Title: $title');
      print('🔔   Body: $body');
      print('🔔   Payload: ${message.data.toString()}');
      
      print('🔔 Calling flutterLocalNotificationsPlugin.show()...');
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: message.data.toString(),
      );
      print('🔔 flutterLocalNotificationsPlugin.show() completed');

      print('✅ Local notification displayed successfully with ID: $notificationId');
      
      // Log successful notification display
      print('🔔 Logging successful notification display to Analytics...');
      analytics.logEvent(
        name: 'local_notification_displayed',
        parameters: {
          'notification_id': notificationId,
          'message_id': message.messageId ?? 'unknown',
        },
      );
      print('🔔 Analytics event logged');
      
    } catch (e) {
      print('❌ ERROR showing local notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Log notification display error
      analytics.logEvent(
        name: 'local_notification_error',
        parameters: {
          'error': e.toString(),
          'message_id': message.messageId ?? 'unknown',
        },
      );
    }
    
    print('🔔 ============ SHOW LOCAL NOTIFICATION END ============');
  }

  static String? get fcmToken => _fcmToken;

  // Refresh FCM token manually
  static Future<String?> refreshToken() async {
    print('🔄 ============ REFRESH TOKEN START ============');
    
    try {
      print('🔄 Forcing FCM token refresh...');
      
      // Delete old token
      print('🔄 Deleting old token...');
      await _messaging?.deleteToken();
      print('🔄 Old token deleted');
      
      // Get fresh token
      print('🔄 Getting fresh token...');
      _fcmToken = await _messaging?.getToken();
      print('🎯 Token refreshed manually: $_fcmToken');
      
      // Log manual token refresh
      analytics.logEvent(name: 'fcm_token_manual_refresh');
      
      print('🔄 ============ REFRESH TOKEN END (SUCCESS) ============');
      return _fcmToken;
    } catch (e) {
      print('❌ Error refreshing token: $e');
      print('🔄 ============ REFRESH TOKEN END (ERROR) ============');
      return null;
    }
  }

  static Future<bool> sendTokenToBackend(String authToken) async {
    print('📡 ============ SEND TOKEN TO BACKEND START ============');
    
    // Always get fresh token before sending
    String? freshToken = await refreshToken();
    if (freshToken != null) {
      bool result = await _sendTokenToBackend(freshToken, authToken);
      print('📡 ============ SEND TOKEN TO BACKEND END ============');
      return result;
    } else {
      print('❌ Fresh token is null, cannot send to backend');
      print('📡 ============ SEND TOKEN TO BACKEND END (FAILED) ============');
      return false;
    }
  }

  static Future<bool> _sendTokenToBackend(String fcmToken, String authToken) async {
    print('📤 ============ BACKEND API CALL START ============');
    
    try {
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      
      print('📤 Sending FCM token to backend: ${fcmToken.substring(0, 20)}...');
      print('📤 API URL: $baseUrl/api/update-fcm-token/');
      print('📤 Auth token: ${authToken.substring(0, 10)}...');
      
      final response = await dio.post(
        '$baseUrl/api/update-fcm-token/',
        data: {'fcm_token': fcmToken},
        options: Options(
          headers: {'Authorization': 'Token $authToken'},
          contentType: Headers.jsonContentType,
        ),
      );

      print('📤 Response status code: ${response.statusCode}');
      print('📤 Response data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ FCM token sent to backend successfully');
        
        // Log successful token update
        analytics.logEvent(name: 'fcm_token_backend_update_success');
        
        print('📤 ============ BACKEND API CALL END (SUCCESS) ============');
        return true;
      } else {
        print('❌ Failed to send FCM token: ${response.statusCode}');
        
        // Log token update failure
        analytics.logEvent(
          name: 'fcm_token_backend_update_failed',
          parameters: {'status_code': response.statusCode ?? -1},
        );
        
        print('📤 ============ BACKEND API CALL END (FAILED) ============');
        return false;
      }
    } catch (e) {
      print('❌ Error sending FCM token to backend: $e');
      if (e is DioException) {
        print('❌ Dio error response: ${e.response?.data}');
        print('❌ Dio error status: ${e.response?.statusCode}');
      }
      
      // Log token update error
      analytics.logEvent(
        name: 'fcm_token_backend_update_error',
        parameters: {'error': e.toString()},
      );
      
      print('📤 ============ BACKEND API CALL END (ERROR) ============');
      return false;
    }
  }

  // Force complete token refresh and backend update
  static Future<bool> forceTokenRefreshAndUpdate() async {
    print('🔄 ============ FORCE TOKEN REFRESH AND UPDATE START ============');
    
    try {
      // Get fresh token
      String? newToken = await refreshToken();
      
      if (newToken != null) {
        String? authToken = await storage.read(key: 'auth_token_jwt') ?? 
                           await storage.read(key: 'auth_token');
        
        if (authToken != null && authToken.isNotEmpty) {
          bool sent = await _sendTokenToBackend(newToken, authToken);
          if (sent) {
            print('✅ Token refresh and backend update completed successfully');
            print('🔄 ============ FORCE TOKEN REFRESH AND UPDATE END (SUCCESS) ============');
            return true;
          }
        } else {
          print('❌ No auth token found');
        }
      } else {
        print('❌ Failed to get fresh token');
      }
      
      print('❌ Token refresh failed');
      print('🔄 ============ FORCE TOKEN REFRESH AND UPDATE END (FAILED) ============');
      return false;
    } catch (e) {
      print('❌ Error in forced token refresh: $e');
      print('🔄 ============ FORCE TOKEN REFRESH AND UPDATE END (ERROR) ============');
      return false;
    }
  }

  // Test local notification
  static Future<void> testNotification() async {
    print('🧪 ============ TEST NOTIFICATION START ============');
    
    try {
      print('🧪 Creating test notification details...');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        ticker: 'Iron Board Test',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      print('🧪 Showing test notification with ID: $notificationId');

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        '🧪 Test Notification',
        'This is a test notification from Iron Board app. If you see this, local notifications are working!',
        platformChannelSpecifics,
      );

      print('✅ Test notification displayed with ID: $notificationId');
      
      // Log test notification
      analytics.logEvent(
        name: 'test_notification_sent',
        parameters: {'notification_id': notificationId},
      );
      
      print('🧪 ============ TEST NOTIFICATION END (SUCCESS) ============');
    } catch (e) {
      print('❌ Error displaying test notification: $e');
      print('🧪 ============ TEST NOTIFICATION END (ERROR) ============');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    print('🎨 Theme toggle requested');
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    print('🎨 Theme changed to: $_themeMode');
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building MyApp widget');
    
    return MaterialApp(
      title: 'Iron Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      home: SplashScreen(toggleTheme: toggleTheme),
      routes: {
        '/login': (context) => LoginScreen(toggleTheme: toggleTheme),
        '/dashboard': (context) => DashboardScreen(toggleTheme: toggleTheme),
      },
      // Set navigation observer for Firebase Analytics
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FCMService.analytics),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SplashScreen({super.key, required this.toggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    print('📱 SplashScreen initState called');

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    _routeByAuthToken();
  }

  Future<void> _routeByAuthToken() async {
    print('🔐 ============ AUTH TOKEN ROUTING START ============');
    
    await Future.delayed(const Duration(seconds: 2));
    print('🔐 Splash screen delay completed');
    
    print('🔐 Reading auth tokens from storage...');
    String? token = await storage.read(key: 'auth_token_jwt');
    if (token == null || token.isEmpty) {
      token = await storage.read(key: 'auth_token');
    }
    
    print('🔐 Auth token found: ${token != null && token.isNotEmpty}');
    if (token != null) {
      print('🔐 Token preview: ${token.substring(0, 10)}...');
    }
    
    if (mounted) {
      if (token != null && token.isNotEmpty) {
        print('🔐 User is logged in, sending FCM token to backend...');
        // If user is already logged in, send fresh FCM token to backend
        bool tokenSent = await FCMService.sendTokenToBackend(token);
        print('📡 FCM token sent on app start: $tokenSent');
        
        // Log successful login with existing token
        FCMService.analytics.logEvent(
          name: 'auto_login_success',
          parameters: {'fcm_token_sent': tokenSent},
        );
        
        print('🔐 Navigating to dashboard...');
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        print('🔐 No auth token found, navigating to login...');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      print('🔐 Widget is not mounted, skipping navigation');
    }
    
    print('🔐 ============ AUTH TOKEN ROUTING END ============');
  }

  @override
  void dispose() {
    print('📱 SplashScreen dispose called');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FadeTransition(
            opacity: _animation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Initializing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              onPressed: () {
                print('🎨 Theme toggle button pressed');
                widget.toggleTheme();
              },
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                size: 30,
              ),
            ),
          ),
          // FCM Token Refresh Button (for testing)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () async {
                  print('🔄 Manual FCM token refresh button pressed');
                  bool success = await FCMService.forceTokenRefreshAndUpdate();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 
                          '✅ FCM Token refreshed successfully!' : 
                          '❌ Failed to refresh FCM token'
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'Refresh FCM Token',
              ),
            ),
          ),
          // Test notification button - VERY IMPORTANT FOR TESTING
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              heroTag: "test_notification",
              onPressed: () async {
                print('🧪 Test notification button pressed');
                await FCMService.testNotification();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🧪 Test notification sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Icon(Icons.notifications_active),
              tooltip: 'Test Local Notification',
            ),
          ),
          // Debug info in development
          if (const bool.fromEnvironment('dart.vm.product') == false)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token: ${FCMService.fcmToken?.substring(0, 30) ?? 'Not available'}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '🔄 Refresh (top-left) • 🧪 Test (floating button)',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
