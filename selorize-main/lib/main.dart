import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:selorize/firebase_options.dart';
import 'package:selorize/service/notification_service.dart';
import 'package:selorize/service/fcm_token_service.dart';
import 'package:selorize/view/state_selection_view.dart';
import 'package:selorize/view/home_view.dart';
import 'package:selorize/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'selorize_main_channel',
  'Selorize Notifications',
  description: 'Selorize app notifications',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _pendingNotificationsPageOpen = false;
bool _isOpeningNotificationsPage = false;

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppNotificationStore.init();
  await _saveNotification(message);
}

String _messageTitle(RemoteMessage message) =>
    message.notification?.title?.trim().isNotEmpty == true
    ? message.notification!.title!
    : message.data['title']?.toString() ??
          message.data['heading']?.toString() ??
          'Selorize';

String _messageBody(RemoteMessage message) =>
    message.notification?.body?.trim().isNotEmpty == true
    ? message.notification!.body!
    : message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          message.data['description']?.toString() ??
          message.data['text']?.toString() ??
          '';

Future<void> _saveNotification(RemoteMessage message) =>
    AppNotificationStore.add(
      id: message.messageId,
      title: _messageTitle(message),
      body: _messageBody(message),
    );

Future<void> _showBanner(RemoteMessage message) async {
  if (kIsWeb) return;
  final title = _messageTitle(message);
  final body = _messageBody(message);
  if (title.isEmpty && body.isEmpty) return;

  await _localNotifications.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: message.notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

void _openNotificationsPage() {
  _pendingNotificationsPageOpen = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _flushNotificationsPageOpen();
  });
  _flushNotificationsPageOpen();
}

Future<void> _flushNotificationsPageOpen() async {
  if (!_pendingNotificationsPageOpen || _isOpeningNotificationsPage) return;

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  _isOpeningNotificationsPage = true;
  _pendingNotificationsPageOpen = false;

  await AppNotificationStore.markAllRead();
  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'notifications'),
      builder: (_) => const NotificationsPage(),
    ),
  );

  _isOpeningNotificationsPage = false;
}


Future<void> _setupLocalNotifications() async {
  if (kIsWeb) return;
  await _localNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    ),
    // FOREGROUND: local notification tap → NotificationsPage
    onDidReceiveNotificationResponse: (_) => _openNotificationsPage(),
  );

  // Android channel create karo
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_channel);

  // Android notification permission maango
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

Future<void> _setupFirebaseMessaging() async {
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
  }
  await FcmTokenService.initialize();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppNotificationStore.init();
  await _setupLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await _setupFirebaseMessaging();

  FirebaseMessaging.onMessage.listen((message) async {
    await _saveNotification(message);
    await _showBanner(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    await _saveNotification(message);
    _openNotificationsPage();
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  final localLaunchDetails = kIsWeb
      ? null
      : await _localNotifications.getNotificationAppLaunchDetails();
  final openedFromLocalNotification =
      localLaunchDetails?.didNotificationLaunchApp ?? false;
  if (initialMessage != null) {
    await _saveNotification(initialMessage);
  }

  runApp(const MyApp());

  if (initialMessage != null || openedFromLocalNotification) {
    _openNotificationsPage();
  }
}

// App

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel()..loadSavedUser(),
      child: MaterialApp(
        title: 'SeloRize',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A78A8)),
          useMaterial3: true,
        ),
        home: const StartupSplash(),
      ),
    );
  }
}

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.84,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      setState(() => _showHome = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _showHome
          ? const AuthGate(key: ValueKey('authGate'))
          : Scaffold(
              key: const ValueKey('startupSplash'),
              backgroundColor: Colors.white,
              body: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 1.15,
                      child: Image.asset(
                        'assets/start_animation.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, child) {
        if (vm.isCheckingSavedUser) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (vm.selectedCity == null || vm.selectedCity!.isEmpty) {
          return const StateSelectionView();
        }
        return const HomeScreen();
      },
    );
  }
}