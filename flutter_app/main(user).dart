// lib/main.dart - USER APP
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// ============================ FIREBASE CONFIGURATION ============================
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyDWRu3oHxEEQUocBSd5upvmXEinS-KzwTQ",
  appId: "1:308397605369:android:7dfde87ca0e6fd0e02fd28",
  messagingSenderId: "308397605369",
  projectId: "hethongkho-39e4f",
  databaseURL:
      "https://hethongkho-39e4f-default-rtdb.asia-southeast1.firebasedatabase.app",
  storageBucket: "hethongkho-39e4f.appspot.com",
);

// ============================ LOCAL NOTIFICATIONS ONLY ============================
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// === KHỞI TẠO LOCAL NOTIFICATIONS ===
Future<void> _initializeNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(initializationSettings);

    // Request permission (Android 13+)
    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestPermission();

    print('🔔 Đã khởi tạo local notifications giống Owner App');
  } catch (e) {
    print('🔴 Lỗi khởi tạo notifications: $e');
  }
}

/// === HIỂN THỊ LOCAL NOTIFICATION ===
Future<void> _showNotification(String title, String body) async {
  try {
    const android = AndroidNotificationDetails(
      'default',
      'General',
      importance: Importance.high,
      priority: Priority.high,
      channelDescription: 'Kênh thông báo chính',
      playSound: true,
      enableVibration: true,
    );
    const detail = NotificationDetails(android: android);

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      detail,
    );

    print('📱 Hiển thị thông báo: $title');
  } catch (e) {
    print('🔴 Lỗi hiển thị thông báo: $e');
  }
}

/// === GỬI CẢNH BÁO LOCAL ===
Future<void> _sendLocalAlert(String title, String body, String type,
    {Map<String, dynamic>? data}) async {
  print('🚨 Gửi cảnh báo local: $title - $body - Type: $type');

  // 1. Hiển thị notification local
  await _showNotification(title, body);

  // 2. Lưu log vào Firebase
  try {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    await db.child('alert_logs').push().set({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': ServerValue.timestamp,
      'sent_via_fcm': false,
      'sent_by': 'user_app',
      'data': data,
    });
    print('📝 Đã lưu log cảnh báo');
  } catch (e) {
    print('⚠️ Lỗi lưu log cảnh báo: $e');
  }
}

// ============================ FIREBASE INITIALIZATION ============================
Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      print('🟡 Đang khởi tạo Firebase cho UserApp...');
      await Firebase.initializeApp(
        name: 'UserApp',
        options: firebaseConfig,
      );
      print('🟢 Firebase UserApp khởi tạo thành công');
    } else {
      print('🟢 Sử dụng Firebase UserApp instance đã tồn tại');
      Firebase.app('UserApp');
    }
  } catch (e) {
    print('🔴 Lỗi khởi tạo Firebase UserApp: $e');
    try {
      await Firebase.initializeApp();
      print('🟢 Firebase initialized without name');
    } catch (e2) {
      print('🔴 Firebase fallback also failed: $e2');
    }
  }
}

// ============================ MAIN FUNCTION ============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Bắt đầu khởi tạo ứng dụng USER (hethongkho.ute)...');

  try {
    // KHỞI TẠO FIREBASE
    await _initializeFirebase();
    print('✅ Firebase UserApp initialized successfully');

    // KHỞI TẠO LOCAL NOTIFICATIONS
    await _initializeNotifications();
    print('✅ Notifications initialized successfully');

    // KHÔNG CHECK THÔNG BÁO TRONG MAIN() - SẼ CHECK SAU KHI USER READY
    print(
        'ℹ️ Không kiểm tra thông báo trong main() - sẽ check sau khi user ready');

    print('🎉 Ứng dụng USER khởi tạo thành công');
    runApp(const UserApp());
  } catch (e, stack) {
    print('🔴 Lỗi khởi tạo ứng dụng USER: $e');
    print('Stack trace: $stack');
    runApp(const UserApp());
  }
}

// ============================ USER APP ============================

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kho Thực Phẩm - User App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================ WELCOME SCREEN ============================

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checkingLogin = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final userId = prefs.getString('userId');
      final userDataJson = prefs.getString('userData');

      if (isLoggedIn && userId != null && userDataJson != null) {
        final userData = Map<String, dynamic>.from(jsonDecode(userDataJson));

        if (userData.isNotEmpty && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainUserScreen(
                userId: userId,
                userData: userData,
              ),
            ),
          );
          return;
        }
      }

      if (mounted) {
        setState(() => _checkingLogin = false);
      }
    } catch (e) {
      print('Error checking login status: $e');
      if (mounted) {
        setState(() => _checkingLogin = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLogin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang kiểm tra đăng nhập...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.store,
                size: 100,
                color: Colors.blue[700],
              ),
              const SizedBox(height: 40),
              const Text(
                'KHO THỰC PHẨM',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ứng dụng quản lý kho thực phẩm thông minh\nGiúp bạn theo dõi và quản lý hàng hóa dễ dàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              _buildFeatureItem(Icons.thermostat, 'Theo dõi nhiệt độ & độ ẩm'),
              _buildFeatureItem(
                  Icons.inventory_2, 'Quản lý hàng hóa trong kho'),
              _buildFeatureItem(Icons.warning, 'Cảnh báo hạn sử dụng'),
              _buildFeatureItem(Icons.notifications, 'Thông báo thông minh'),
              _buildFeatureItem(Icons.qr_code, 'QR Code hàng hóa'),
              _buildFeatureItem(Icons.share, 'Chia sẻ thông tin'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'BẮT ĐẦU ĐĂNG NHẬP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppInfoDialog(),
                  );
                },
                child: const Text('Thông tin ứng dụng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ============================ APP INFO DIALOG ============================

class AppInfoDialog extends StatefulWidget {
  const AppInfoDialog({super.key});

  @override
  State<AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<AppInfoDialog> {
  Map<String, dynamic> _ownerInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerInfo();
  }

  Future<void> _loadOwnerInfo() async {
    try {
      final DatabaseReference db =
          FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
      final snapshot = await db.child('owner_info').get();

      if (snapshot.exists) {
        setState(() {
          _ownerInfo = _convertData(snapshot.value);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading owner info: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _convertData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      final result = <String, dynamic>{};
      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          result[key.toString()] = _convertData(value);
        } else {
          result[key.toString()] = value;
        }
      }
      return result;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info, color: Colors.blue),
          SizedBox(width: 8),
          Text('Thông tin ứng dụng'),
        ],
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kho Thực Phẩm - User App',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ứng dụng quản lý và theo dõi kho thực phẩm thông minh, giúp người dùng dễ dàng quản lý hàng hóa và nhận cảnh báo về điều kiện bảo quản.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (_ownerInfo.isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'Thông tin chủ kho:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_ownerInfo['name'] != null)
                      _buildInfoItem('Chủ kho:', _ownerInfo['name'].toString()),
                    if (_ownerInfo['phone'] != null)
                      _buildInfoItem(
                          'Liên hệ:', _ownerInfo['phone'].toString()),
                    if (_ownerInfo['email'] != null)
                      _buildInfoItem('Email:', _ownerInfo['email'].toString()),
                    if (_ownerInfo['address'] != null)
                      _buildInfoItem(
                          'Địa chỉ:', _ownerInfo['address'].toString()),
                  ] else
                    const Text(
                      'Không thể tải thông tin chủ kho',
                      style: TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Phiên bản: 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 70),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// ============================ LOGIN SCREEN ============================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late DatabaseReference _db;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
  }

  Map<String, dynamic> _convertData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      final result = <String, dynamic>{};
      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          result[key.toString()] = _convertData(value);
        } else {
          result[key.toString()] = value;
        }
      }
      return result;
    }
    return {};
  }

  Future<void> _handleFailedLoginAttempt(String warehousePrefix) async {
    try {
      final failPath = 'kho$warehousePrefix/fail$warehousePrefix';
      final failSnapshot = await _db.child(failPath).get();
      int currentFails =
          failSnapshot.exists ? (failSnapshot.value as int?) ?? 0 : 0;
      int newFails = currentFails + 1;

      await _db.child(failPath).set(newFails);

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtySeconds = 30 * 1000;

      if (newFails >= 10) {
        await _db
            .child('kho$warehousePrefix/childlock$warehousePrefix')
            .set(true);

        await _sendLocalAlert(
          '🚨 CẢNH BÁO KHẨN CẤP',
          'Kho $warehousePrefix: Phát hiện $newFails lần nhập sai mật khẩu. ĐÃ KÍCH HOẠT CHẾ ĐỘ KHÓA AN TOÀN!',
          'security_lock_activated',
          data: {
            'warehouse': warehousePrefix,
            'failed_attempts': newFails,
            'action': 'childlock_activated',
          },
        );
      } else if (newFails >= 5) {
        await _sendLocalAlert(
          '⚠️ Cảnh báo nhẹ',
          'Kho $warehousePrefix: Đã có $newFails lần nhập sai mật khẩu.',
          'failed_login_warning',
          data: {
            'warehouse': warehousePrefix,
            'failed_attempts': newFails,
          },
        );
      }
    } catch (e) {
      print('Error handling failed login: $e');
    }
  }

  Future<void> _resetFailedLoginAttempts(String warehousePrefix) async {
    try {
      await _db.child('kho$warehousePrefix/fail$warehousePrefix').set(0);
    } catch (e) {
      print('Error resetting failed attempts: $e');
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập đầy đủ thông tin đăng nhập');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usersSnapshot = await _db.child('owner/users').get();

      if (!usersSnapshot.exists) {
        _showError('Không tìm thấy người dùng nào');
        return;
      }

      final usersData = _convertData(usersSnapshot.value);
      bool foundUser = false;
      Map<String, dynamic>? userData;
      String? userId;

      for (final entry in usersData.entries) {
        final user = _convertData(entry.value);
        final userUsername = user['username']?.toString() ?? '';
        final userPassword = user['password']?.toString() ?? '';

        if (userUsername == username && userPassword == password) {
          foundUser = true;
          userData = user;
          userId = entry.key;
          break;
        }
      }

      if (!foundUser) {
        _showError('Sai tên đăng nhập hoặc mật khẩu');

        await _handleFailedLoginAttempt('1');
        await _handleFailedLoginAttempt('2');
        return;
      }

      final status = userData!['status']?.toString() ?? '';
      if (status != 'active') {
        String errorMessage = 'Tài khoản của bạn đã bị khóa';
        if (status == 'expired') {
          errorMessage = 'Tài khoản của bạn đã hết hạn';
        }
        _showError(errorMessage);
        return;
      }

      final endDateStr = userData['end_date']?.toString();
      if (endDateStr != null) {
        try {
          final endDate = DateTime.parse(endDateStr);
          final today = DateTime.now();
          final daysLeft = endDate.difference(today).inDays;

          if (daysLeft < 0) {
            await _db.child('owner/users/$userId/status').set('expired');
            _showError('Tài khoản của bạn đã hết hạn và bị khóa tự động');
            return;
          } else if (daysLeft <= 7) {
            _showWarning('Tài khoản của bạn còn $daysLeft ngày sử dụng');
          }
        } catch (e) {
          print('Error checking expiry date: $e');
        }
      }

      await _resetFailedLoginAttempts('1');
      await _resetFailedLoginAttempts('2');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId!);
      await prefs.setString('userData', jsonEncode(userData));

      print('🟢 Đăng nhập thành công: $userId - ${userData['full_name']}');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainUserScreen(
              userId: userId!,
              userData: userData!,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi đăng nhập: $e');
      print('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đăng nhập',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng đăng nhập để tiếp tục',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ĐĂNG NHẬP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AppInfoDialog(),
                    );
                  },
                  child: const Text('Thông tin ứng dụng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ MAIN USER SCREEN ============================

class MainUserScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const MainUserScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<MainUserScreen> createState() => _MainUserScreenState();
}

class _MainUserScreenState extends State<MainUserScreen> {
  Map<String, dynamic> _warehouseData = {};
  Map<String, dynamic> _productsData = {};
  Map<String, dynamic> _rentalSettings = {};
  Map<String, dynamic> _ownerInfo = {};

  bool _isLoading = true;
  bool _userReady = false;
  bool _accessKho1 = false;
  bool _accessKho2 = false;

  late DatabaseReference _db;

  // Timers
  Timer? _rentalCheckTimer;
  Timer? _environmentCheckTimer;
  Timer? _cleanupTimer;

  // Last warnings
  final Map<String, DateTime> _lastRentalWarning = {};
  final Map<String, DateTime> _lastEnvironmentWarning = {};
  final Map<String, DateTime> _lastProductWarning = {};

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    print('📱 MainUserScreen initState - user: ${widget.userId}');

    // 1. KHỞI TẠO USER CONTEXT TRƯỚC
    _initUserContext().then((_) {
      if (_userReady) {
        // 2. SETUP REALTIME UPDATES
        _setupRealtime();

        // 3. START TIMERS
        _startRentalTimer();
        _startEnvironmentTimer();
        _startCleanupTimer();

        // 4. CHECK CẢNH BÁO NGAY LẦN ĐẦU
        _checkRentalExpiry();
        _checkEnvironmentAlerts();
        _checkProductExpiry();

        // 5. CLEANUP OLD ALERTS
        _cleanupOldAlerts();
      }
    });
  }

  @override
  void dispose() {
    _rentalCheckTimer?.cancel();
    _environmentCheckTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // ========== HELPERS ==========

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  // ========== TIMER MANAGEMENT ==========

  void _startRentalTimer() {
    _rentalCheckTimer?.cancel();
    _rentalCheckTimer = Timer.periodic(const Duration(hours: 12), (_) {
      _checkRentalExpiry();
    });
  }

  void _startEnvironmentTimer() {
    _environmentCheckTimer?.cancel();
    _environmentCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkEnvironmentAlerts();
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _cleanupOldAlerts();
    });
  }

  // ========== LOAD USER CONTEXT ==========

  Future<void> _initUserContext() async {
    try {
      // Load quyền truy cập từ user data
      setState(() {
        _accessKho1 = widget.userData['access_kho1'] == true;
        _accessKho2 = widget.userData['access_kho2'] == true;
        _userReady = true;
      });

      print('✅ User context ready: kho1=$_accessKho1, kho2=$_accessKho2');

      // Load dữ liệu kho mà user có quyền
      await _loadWarehouseData();

      // Load rental settings
      final settingsSnapshot = await _db.child('system/rental_settings').get();
      if (settingsSnapshot.exists) {
        setState(() {
          _rentalSettings = _asMap(settingsSnapshot.value);
        });
      } else {
        setState(() {
          _rentalSettings = {'warning_days': 7, 'auto_lock_after_expiry': true};
        });
      }

      // Load owner info
      final ownerSnapshot = await _db.child('owner_info').get();
      if (ownerSnapshot.exists) {
        setState(() {
          _ownerInfo = _asMap(ownerSnapshot.value);
        });
      }
    } catch (e) {
      print('🔴 Lỗi khởi tạo user context: $e');
    }
  }

  // ========== LOAD WAREHOUSE DATA ==========

  Future<void> _loadWarehouseData() async {
    try {
      setState(() => _isLoading = true);

      // CHỈ TẢI DỮ LIỆU KHO MÀ USER CÓ QUYỀN
      if (_accessKho1) {
        final kho1Snapshot = await _db.child('kho1').get();
        _warehouseData['kho1'] = _asMap(kho1Snapshot.value);
      }

      if (_accessKho2) {
        final kho2Snapshot = await _db.child('kho2').get();
        _warehouseData['kho2'] = _asMap(kho2Snapshot.value);
      }

      // CHỈ TẢI HÀNG HÓA KHO MÀ USER CÓ QUYỀN
      if (_accessKho1) {
        final productsKho1Snapshot = await _db.child('products/kho1').get();
        _productsData['kho1'] = _asMap(productsKho1Snapshot.value);
      }

      if (_accessKho2) {
        final productsKho2Snapshot = await _db.child('products/kho2').get();
        _productsData['kho2'] = _asMap(productsKho2Snapshot.value);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Load warehouse error: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Lỗi khi tải dữ liệu');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ========== SETUP REALTIME UPDATES ==========

  void _setupRealtime() {
    // CHỈ LẮNG NGHE KHO MÀ USER CÓ QUYỀN
    if (_accessKho1) {
      _db.child('kho1').onValue.listen((event) {
        if (mounted) {
          setState(() => _warehouseData['kho1'] = _asMap(event.snapshot.value));
        }
      });
    }

    if (_accessKho2) {
      _db.child('kho2').onValue.listen((event) {
        if (mounted) {
          setState(() => _warehouseData['kho2'] = _asMap(event.snapshot.value));
        }
      });
    }

    // CHỈ LẮNG NGHE HÀNG HÓA KHO MÀ USER CÓ QUYỀN
    if (_accessKho1) {
      _db.child('products/kho1').onValue.listen((event) {
        if (mounted) {
          setState(() => _productsData['kho1'] = _asMap(event.snapshot.value));
        }
      });
    }

    if (_accessKho2) {
      _db.child('products/kho2').onValue.listen((event) {
        if (mounted) {
          setState(() => _productsData['kho2'] = _asMap(event.snapshot.value));
        }
      });
    }
  }

  // ========== CẢNH BÁO THUÊ BAO ==========

  Future<void> _checkRentalExpiry() async {
    if (!_userReady) return;

    final today = DateTime.now();
    final warningDays = (_rentalSettings['warning_days'] ?? 7) as int;

    // CHỈ KIỂM TRA USER HIỆN TẠI
    final user = widget.userData;
    if ((user['status'] ?? '') != 'active') return;

    final endStr = (user['end_date'] ?? '') as String;
    try {
      final end = DateFormat('yyyy-MM-dd').parse(endStr);
      final daysLeft = end.difference(today).inDays;

      final lastWarning = _lastRentalWarning[widget.userId];

      if (lastWarning != null &&
          DateTime.now().difference(lastWarning).inHours < 12) {
        return;
      }

      if (daysLeft <= warningDays && daysLeft >= 0) {
        final title = '⏰ Thuê bao sắp hết hạn';
        final body =
            '${user['full_name'] ?? 'Người dùng'} còn $daysLeft ngày. Hết hạn: ${DateFormat('dd/MM/yyyy').format(end)}';

        await _sendLocalAlert(title, body, 'rental_warning');
        _lastRentalWarning[widget.userId] = DateTime.now();
      }
      if (daysLeft < 0) {
        await _handleExpiredRental(user);
        final title = '🔒 Thuê bao đã hết hạn';
        final body =
            '${user['full_name'] ?? 'Người dùng'} đã hết hạn. Tài khoản bị khóa.';

        await _sendLocalAlert(title, body, 'rental_expired');
        _lastRentalWarning[widget.userId] = DateTime.now();
      }
    } catch (_) {}
  }

  Future<void> _handleExpiredRental(Map<String, dynamic> user) async {
    if (_rentalSettings['auto_lock_after_expiry'] == true) {
      await _db.child('owner/users/${widget.userId}/status').set('expired');
    }
  }

  // ========== CẢNH BÁO MÔI TRƯỜNG ==========

  void _checkEnvironmentAlerts() {
    if (!_userReady) return;

    // CHỈ CHECK KHO USER ĐƯỢC PHÉP
    if (_accessKho1) {
      _checkSingleWarehouseAlert('kho1', _warehouseData['kho1']);
    }
    if (_accessKho2) {
      _checkSingleWarehouseAlert('kho2', _warehouseData['kho2']);
    }
  }

  void _checkSingleWarehouseAlert(String warehouse, Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final prefix = warehouse == 'kho1' ? '1' : '2';
    final currentTemp =
        double.tryParse(data['temp$prefix']?.toString() ?? '0') ?? 0;
    final currentHum =
        double.tryParse(data['hum$prefix']?.toString() ?? '0') ?? 0;
    final highTemp =
        double.tryParse(data['hightemp$prefix']?.toString() ?? '0') ?? 0;
    final highHum =
        double.tryParse(data['highhum$prefix']?.toString() ?? '0') ?? 0;
    final lowTemp =
        double.tryParse(data['lowtemp$prefix']?.toString() ?? '0') ?? 0;
    final lowHum =
        double.tryParse(data['lowhum$prefix']?.toString() ?? '0') ?? 0;

    final lastWarningKey = '$warehouse-temp-$currentTemp-hum-$currentHum';
    final lastWarning = _lastEnvironmentWarning[lastWarningKey];

    if (lastWarning != null &&
        DateTime.now().difference(lastWarning).inSeconds < 30) {
      return;
    }

    if (currentTemp >= highTemp) {
      _sendEnvironmentAlert(
          warehouse,
          '⚠️ Cảnh báo nhiệt độ CAO',
          'Nhiệt độ ${currentTemp.toStringAsFixed(1)}°C vượt ngưỡng cao ${highTemp}°C',
          'temperature_high');
      _lastEnvironmentWarning[lastWarningKey] = DateTime.now();
    } else if (currentTemp <= lowTemp) {
      _sendEnvironmentAlert(
          warehouse,
          '⚠️ Cảnh báo nhiệt độ THẤP',
          'Nhiệt độ ${currentTemp.toStringAsFixed(1)}°C dưới ngưỡng thấp ${lowTemp}°C',
          'temperature_low');
      _lastEnvironmentWarning[lastWarningKey] = DateTime.now();
    }

    if (currentHum >= highHum) {
      _sendEnvironmentAlert(
          warehouse,
          '⚠️ Cảnh báo độ ẩm CAO',
          'Độ ẩm ${currentHum.toStringAsFixed(1)}% vượt ngưỡng cao ${highHum}%',
          'humidity_high');
      _lastEnvironmentWarning[lastWarningKey] = DateTime.now();
    } else if (currentHum <= lowHum) {
      _sendEnvironmentAlert(
          warehouse,
          '⚠️ Cảnh báo độ ẩm THẤP',
          'Độ ẩm ${currentHum.toStringAsFixed(1)}% dưới ngưỡng thấp ${lowHum}%',
          'humidity_low');
      _lastEnvironmentWarning[lastWarningKey] = DateTime.now();
    }

    if (data['alarm$prefix'] == true) {
      _sendEnvironmentAlert(warehouse, '🚨 BÁO ĐỘNG',
          'Kho $warehouse đang báo động!', 'alarm_triggered');
      _lastEnvironmentWarning[lastWarningKey] = DateTime.now();
    }
  }

  void _sendEnvironmentAlert(
      String warehouse, String title, String body, String type) {
    final fullTitle = '${warehouse.toUpperCase()}: $title';
    _sendLocalAlert(fullTitle, body, type);
  }

  // ========== CẢNH BÁO HÀNG HÓA HẾT HẠN ==========

  Future<void> _checkProductExpiry() async {
    if (!_userReady) return;

    final today = DateTime.now();

    // CHỈ KIỂM TRA KHO USER CÓ QUYỀN
    if (_accessKho1) {
      await _checkProductsInWarehouse(
          'Kho 1', '1', _productsData['kho1'], today);
    }
    if (_accessKho2) {
      await _checkProductsInWarehouse(
          'Kho 2', '2', _productsData['kho2'], today);
    }
  }

  Future<void> _checkProductsInWarehouse(String warehouseName, String prefix,
      Map<String, dynamic> products, DateTime today) async {
    if (products.isEmpty) return;

    for (final entry in products.entries) {
      final productId = entry.key;
      final productData = _asMap(entry.value);

      final expiryDateStr = productData['expiry_date']?.toString();
      if (expiryDateStr != null) {
        try {
          final expiryDate = DateFormat('yyyy-MM-dd').parse(expiryDateStr);
          final daysLeft = expiryDate.difference(today).inDays;

          final lastWarningKey = '$productId-$daysLeft';
          final lastWarning = _lastProductWarning[lastWarningKey];

          if (lastWarning != null &&
              DateTime.now().difference(lastWarning).inHours < 12) {
            continue;
          }

          if (daysLeft <= 7 && daysLeft > 0) {
            await _sendLocalAlert(
              '⚠️ Hàng hóa sắp hết hạn',
              '${productData['name']} trong $warehouseName còn $daysLeft ngày. HSD: ${DateFormat('dd/MM/yyyy').format(expiryDate)}',
              'product_expiry_warning',
              data: {
                'product_id': productId,
                'product_name': productData['name'],
                'warehouse': warehouseName,
                'warehouse_prefix': prefix,
                'days_left': daysLeft,
                'expiry_date': expiryDateStr,
              },
            );
            _lastProductWarning[lastWarningKey] = DateTime.now();
          } else if (daysLeft < 0) {
            await _sendLocalAlert(
              '🚨 Hàng hóa đã hết hạn',
              '${productData['name']} trong $warehouseName đã hết hạn sử dụng! HSD: ${DateFormat('dd/MM/yyyy').format(expiryDate)}',
              'product_expired',
              data: {
                'product_id': productId,
                'product_name': productData['name'],
                'warehouse': warehouseName,
                'warehouse_prefix': prefix,
                'expiry_date': expiryDateStr,
              },
            );
            _lastProductWarning[lastWarningKey] = DateTime.now();
          }
        } catch (_) {}
      }
    }
  }

  // ========== CLEANUP OLD ALERTS ==========

  Future<void> _cleanupOldAlerts() async {
    try {
      final cutoffTime = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;

      final alertsSnapshot = await _db.child('alert_logs').get();
      if (alertsSnapshot.exists) {
        final alerts = _asMap(alertsSnapshot.value);

        int deletedCount = 0;
        for (final entry in alerts.entries) {
          final alertId = entry.key;
          final alertData = _asMap(entry.value);
          final timestamp = alertData['timestamp'] ?? 0;

          if (timestamp is int && timestamp < cutoffTime) {
            await _db.child('alert_logs/$alertId').remove();
            deletedCount++;
            print(
                '🗑 Đã xóa alert cũ: $alertId (${DateTime.fromMillisecondsSinceEpoch(timestamp)})');
          }
        }

        if (deletedCount > 0) {
          print('✅ Đã xóa $deletedCount alert logs cũ (quá 30 ngày)');
        }
      }
    } catch (e) {
      print('🔴 Lỗi khi dọn dẹp alerts: $e');
    }
  }

  // ========== HELPER FUNCTIONS FOR QUICK ACTIONS ==========

  // Hàm đếm số cảnh báo
  int _getAlertCount() {
    int count = 0;
    final today = DateTime.now();

    // Đếm cảnh báo môi trường
    if (_accessKho1) {
      final data = _warehouseData['kho1'] ?? {};
      final temp = double.tryParse(data['temp1']?.toString() ?? '0') ?? 0;
      final hum = double.tryParse(data['hum1']?.toString() ?? '0') ?? 0;
      final lowTemp = double.tryParse(data['lowtemp1']?.toString() ?? '0') ?? 0;
      final lowHum = double.tryParse(data['lowhum1']?.toString() ?? '0') ?? 0;
      final highTemp =
          double.tryParse(data['hightemp1']?.toString() ?? '0') ?? 0;
      final highHum = double.tryParse(data['highhum1']?.toString() ?? '0') ?? 0;

      if (temp >= highTemp || temp <= lowTemp) count++;
      if (hum >= highHum || hum <= lowHum) count++;
      if (data['alarm1'] == true) count++;
    }

    if (_accessKho2) {
      final data = _warehouseData['kho2'] ?? {};
      final temp = double.tryParse(data['temp2']?.toString() ?? '0') ?? 0;
      final hum = double.tryParse(data['hum2']?.toString() ?? '0') ?? 0;
      final lowTemp = double.tryParse(data['lowtemp2']?.toString() ?? '0') ?? 0;
      final lowHum = double.tryParse(data['lowhum2']?.toString() ?? '0') ?? 0;
      final highTemp =
          double.tryParse(data['hightemp2']?.toString() ?? '0') ?? 0;
      final highHum = double.tryParse(data['highhum2']?.toString() ?? '0') ?? 0;

      if (temp >= highTemp || temp <= lowTemp) count++;
      if (hum >= highHum || hum <= lowHum) count++;
      if (data['alarm2'] == true) count++;
    }

    // Đếm hàng hóa sắp hết hạn
    for (final warehouse in ['kho1', 'kho2']) {
      if ((warehouse == 'kho1' && !_accessKho1) ||
          (warehouse == 'kho2' && !_accessKho2)) continue;

      final products = _productsData[warehouse] ?? {};
      for (final product in products.values) {
        final productMap = _asMap(product);
        final expiry = productMap['expiry_date'];
        if (expiry != null) {
          try {
            final expiryDate = DateTime.parse(expiry.toString());
            final daysLeft = expiryDate.difference(today).inDays;
            if (daysLeft <= 7 && daysLeft > 0) {
              count++;
            }
          } catch (_) {}
        }
      }
    }

    return count;
  }

  // Hàm hiển thị tìm kiếm hàng hóa
  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductSearchScreen(
        productsData: _productsData,
        accessKho1: _accessKho1,
        accessKho2: _accessKho2,
      ),
    );
  }

  // Hàm hiển thị thông tin chủ kho
  void _showOwnerInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text('Thông tin chủ kho'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ownerInfo.isNotEmpty) ...[
                if (_ownerInfo['name'] != null)
                  _buildOwnerInfoItem('Họ tên:', _ownerInfo['name'].toString()),
                if (_ownerInfo['phone'] != null)
                  _buildOwnerInfoItem('SĐT:', _ownerInfo['phone'].toString()),
                if (_ownerInfo['email'] != null)
                  _buildOwnerInfoItem('Email:', _ownerInfo['email'].toString()),
                if (_ownerInfo['address'] != null)
                  _buildOwnerInfoItem(
                      'Địa chỉ:', _ownerInfo['address'].toString()),
              ] else
                const Text(
                  'Không có thông tin chủ kho',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // ========== LOGOUT ==========

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // ========== UI BUILDERS ==========

  bool get _hasAnyAccess => _accessKho1 || _accessKho2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Thực Phẩm'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWarehouseData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'owner_info') {
                _showOwnerInfoDialog();
              } else if (value == 'alerts') {
                _showAlerts();
              } else if (value == 'settings') {
                _showSettings();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'owner_info',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Thông tin chủ kho'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'alerts',
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 20),
                    SizedBox(width: 8),
                    Text('Xem cảnh báo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Cài đặt'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_hasAnyAccess) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Không có quyền truy cập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Tài khoản của bạn hiện không có quyền truy cập vào bất kỳ kho nào.\nVui lòng liên hệ chủ kho để được cấp quyền.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          if (_accessKho1)
            _buildWarehouseCard('KHO 1', _warehouseData['kho1'] ?? {}, '1',
                _productsData['kho1'] ?? {}),
          if (_accessKho1 && _accessKho2) const SizedBox(height: 16),
          if (_accessKho2)
            _buildWarehouseCard('KHO 2', _warehouseData['kho2'] ?? {}, '2',
                _productsData['kho2'] ?? {}),
          const SizedBox(height: 16),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final today = DateTime.now();
    int daysLeft = 0;
    try {
      final endDateStr = widget.userData['end_date']?.toString();
      if (endDateStr != null) {
        final endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
        daysLeft = endDate.difference(today).inDays;
      }
    } catch (_) {}

    Color statusColor = Colors.green;
    if (widget.userData['status'] == 'expired') {
      statusColor = Colors.red;
    } else if (daysLeft <= 7 && daysLeft >= 0) {
      statusColor = Colors.orange;
    } else if (daysLeft < 0) {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${widget.userData['full_name']?.toString() ?? 'Người dùng'}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quyền truy cập: ${_buildAccessText()}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hết hạn: ${widget.userData['end_date']?.toString() ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (widget.userData['status'] == 'expired')
                    Text(
                      '🔒 Tài khoản đã hết hạn',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    )
                  else if (daysLeft <= 7 && daysLeft >= 0)
                    Text(
                      '⚠️ Còn $daysLeft ngày',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    )
                  else if (daysLeft < 0)
                    Text(
                      '❌ Đã hết hạn $daysLeft ngày',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildAccessText() {
    final accesses = <String>[];
    if (_accessKho1) accesses.add('Kho 1');
    if (_accessKho2) accesses.add('Kho 2');
    return accesses.isEmpty ? 'Không có' : accesses.join(', ');
  }

  Widget _buildWarehouseCard(String name, Map<String, dynamic> data,
      String prefix, Map<String, dynamic> products) {
    if (data.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Đang tải dữ liệu $name...',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final currentTemp =
        double.tryParse(data['temp$prefix']?.toString() ?? '0') ?? 0;
    final currentHum =
        double.tryParse(data['hum$prefix']?.toString() ?? '0') ?? 0;

    final lowTemp =
        double.tryParse(data['lowtemp$prefix']?.toString() ?? '0') ?? 0;
    final lowHum =
        double.tryParse(data['lowhum$prefix']?.toString() ?? '0') ?? 0;
    final highTemp =
        double.tryParse(data['hightemp$prefix']?.toString() ?? '0') ?? 0;
    final highHum =
        double.tryParse(data['highhum$prefix']?.toString() ?? '0') ?? 0;

    final lowTempWarning = currentTemp <= lowTemp;
    final lowHumWarning = currentHum <= lowHum;
    final highTempWarning = currentTemp >= highTemp;
    final highHumWarning = currentHum >= highHum;

    final productCount = products.length;
    final today = DateTime.now();
    int warningProducts = 0;

    for (final product in products.values) {
      final productMap = _asMap(product);
      final expiry = productMap['expiry_date'];
      if (expiry != null) {
        try {
          final expiryDate = DateTime.parse(expiry.toString());
          final daysLeft = expiryDate.difference(today).inDays;
          if (daysLeft <= 7 && daysLeft > 0) {
            warningProducts++;
          }
        } catch (_) {}
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (data['alarm$prefix'] == true)
                  const Icon(Icons.warning, color: Colors.red),
                Icon(
                  data['lock$prefix'] == true ? Icons.lock_open : Icons.lock,
                  color:
                      data['lock$prefix'] == true ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              icon: Icons.thermostat,
              value: '${data['temp$prefix'] ?? 'N/A'}°C',
              status: highTempWarning
                  ? 'warning_high'
                  : lowTempWarning
                      ? 'warning_low'
                      : 'normal',
              label: 'Nhiệt độ',
              warningText: highTempWarning
                  ? 'CAO'
                  : lowTempWarning
                      ? 'THẤP'
                      : null,
            ),
            _buildStatusRow(
              icon: Icons.water_drop,
              value: '${data['hum$prefix'] ?? 'N/A'}%',
              status: highHumWarning
                  ? 'warning_high'
                  : lowHumWarning
                      ? 'warning_low'
                      : 'normal',
              label: 'Độ ẩm',
              warningText: highHumWarning
                  ? 'CAO'
                  : lowHumWarning
                      ? 'THẤP'
                      : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.inventory_2,
                  text: '$productCount SP',
                  color: Colors.blue,
                ),
                if (warningProducts > 0) ...[
                  _buildInfoChip(
                    icon: Icons.warning,
                    text: '$warningProducts SP sắp hết hạn',
                    color: Colors.orange,
                  ),
                ],
                _buildInfoChip(
                  icon: Icons.lightbulb,
                  text: data['light$prefix'] == true ? 'Đèn bật' : 'Đèn tắt',
                  color:
                      data['light$prefix'] == true ? Colors.amber : Colors.grey,
                ),
                if (data['pir$prefix'] != null)
                  _buildInfoChip(
                    icon: Icons.sensors,
                    text: data['pir$prefix'] == true
                        ? 'Có chuyển động'
                        : 'Không chuyển động',
                    color: data['pir$prefix'] == true
                        ? Colors.purple
                        : Colors.grey,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showProducts(context, name, prefix, products);
                      },
                      icon: const Icon(Icons.inventory_2, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Quản lý hàng hóa',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAdvancedControls(context, name, data, prefix);
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cài đặt nâng cao',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String value,
    required String status,
    required String label,
    String? warningText,
  }) {
    Color color = Colors.black;
    if (status == 'warning_high') {
      color = Colors.orange;
    } else if (status == 'warning_low') {
      color = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          if (warningText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color),
              ),
              child: Text(
                warningText,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      {required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'QUẢN LÝ CHUNG',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 CHỨC NĂNG QUẢN LÝ CHUNG
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildManagementButton(
                  icon: Icons.search,
                  title: 'TÌM KIẾM\nHÀNG HÓA',
                  color: Colors.blue,
                  onTap: _showProductSearch,
                ),
                _buildManagementButton(
                  icon: Icons.warning,
                  title: 'CẢNH BÁO\n(${_getAlertCount()})',
                  color: Colors.red,
                  onTap: _showAlerts,
                ),
                _buildManagementButton(
                  icon: Icons.add,
                  title: 'THÊM MỚI\nHÀNG HÓA',
                  color: Colors.green,
                  onTap: () => _showAddProductDialog(context),
                ),
                _buildManagementButton(
                  icon: Icons.person,
                  title: 'THÔNG TIN\nCHỦ KHO',
                  color: Colors.purple,
                  onTap: _showOwnerInfo,
                ),
              ],
            ),

            // Thêm mô tả nhỏ
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Các chức năng quản lý chung cho toàn bộ hệ thống',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProducts(BuildContext context, String warehouseName, String prefix,
      Map<String, dynamic> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductManagementScreen(
          warehouseName: 'kho$prefix',
          warehousePrefix: prefix,
          currentProducts: products,
          userId: widget.userId,
          userName: widget.userData['full_name']?.toString() ?? 'Người dùng',
        ),
      ),
    );
  }

  void _showAdvancedControls(BuildContext context, String warehouseName,
      Map<String, dynamic> data, String prefix) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AdvancedControlScreen(
        warehouseName: warehouseName,
        warehouseData: data,
        prefix: prefix,
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn kho để thêm hàng hóa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_accessKho1)
              ListTile(
                leading: const Icon(Icons.warehouse, color: Colors.blue),
                title: const Text('Kho 1'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddProductForm('1');
                },
              ),
            if (_accessKho2)
              ListTile(
                leading: const Icon(Icons.warehouse, color: Colors.green),
                title: const Text('Kho 2'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddProductForm('2');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddProductForm(String prefix) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        warehousePrefix: prefix,
        userId: widget.userId,
        userName: widget.userData['full_name']?.toString() ?? 'Người dùng',
        onProductAdded: _loadWarehouseData,
      ),
    );
  }

  void _showAlerts() {
    final alerts = <String>[];
    final today = DateTime.now();

    if (_accessKho1) {
      final data = _warehouseData['kho1'] ?? {};
      final temp = double.tryParse(data['temp1']?.toString() ?? '0') ?? 0;
      final hum = double.tryParse(data['hum1']?.toString() ?? '0') ?? 0;

      final lowTemp = double.tryParse(data['lowtemp1']?.toString() ?? '0') ?? 0;
      final lowHum = double.tryParse(data['lowhum1']?.toString() ?? '0') ?? 0;
      final highTemp =
          double.tryParse(data['hightemp1']?.toString() ?? '0') ?? 0;
      final highHum = double.tryParse(data['highhum1']?.toString() ?? '0') ?? 0;

      if (temp >= highTemp) alerts.add('Kho 1: Nhiệt độ CAO ($temp°C)');
      if (temp <= lowTemp) alerts.add('Kho 1: Nhiệt độ THẤP ($temp°C)');
      if (hum >= highHum) alerts.add('Kho 1: Độ ẩm CAO ($hum%)');
      if (hum <= lowHum) alerts.add('Kho 1: Độ ẩm THẤP ($hum%)');
    }

    if (_accessKho2) {
      final data = _warehouseData['kho2'] ?? {};
      final temp = double.tryParse(data['temp2']?.toString() ?? '0') ?? 0;
      final hum = double.tryParse(data['hum2']?.toString() ?? '0') ?? 0;

      final lowTemp = double.tryParse(data['lowtemp2']?.toString() ?? '0') ?? 0;
      final lowHum = double.tryParse(data['lowhum2']?.toString() ?? '0') ?? 0;
      final highTemp =
          double.tryParse(data['hightemp2']?.toString() ?? '0') ?? 0;
      final highHum = double.tryParse(data['highhum2']?.toString() ?? '0') ?? 0;

      if (temp >= highTemp) alerts.add('Kho 2: Nhiệt độ CAO ($temp°C)');
      if (temp <= lowTemp) alerts.add('Kho 2: Nhiệt độ THẤP ($temp°C)');
      if (hum >= highHum) alerts.add('Kho 2: Độ ẩm CAO ($hum%)');
      if (hum <= lowHum) alerts.add('Kho 2: Độ ẩm THẤP ($hum%)');
    }

    for (final warehouse in ['kho1', 'kho2']) {
      if ((warehouse == 'kho1' && !_accessKho1) ||
          (warehouse == 'kho2' && !_accessKho2)) continue;

      final products = _productsData[warehouse] ?? {};
      for (final product in products.values) {
        final productMap = _asMap(product);
        final expiry = productMap['expiry_date'];
        if (expiry != null) {
          try {
            final expiryDate = DateTime.parse(expiry.toString());
            final daysLeft = expiryDate.difference(today).inDays;
            if (daysLeft <= 7 && daysLeft > 0) {
              alerts.add(
                  '${productMap['name']} (${warehouse.toUpperCase()}) còn $daysLeft ngày');
            }
          } catch (_) {}
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cảnh báo hệ thống'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: alerts.isEmpty
              ? const Text('Không có cảnh báo nào')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.warning,
                          size: 20, color: Colors.orange),
                      title: Text(alerts[index]),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showOwnerInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text('Thông tin chủ kho'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ownerInfo.isNotEmpty) ...[
                if (_ownerInfo['name'] != null)
                  _buildInfoItem('Họ tên:', _ownerInfo['name'].toString()),
                if (_ownerInfo['phone'] != null)
                  _buildInfoItem('SĐT:', _ownerInfo['phone'].toString()),
                if (_ownerInfo['email'] != null)
                  _buildInfoItem('Email:', _ownerInfo['email'].toString()),
                if (_ownerInfo['address'] != null)
                  _buildInfoItem('Địa chỉ:', _ownerInfo['address'].toString()),
              ] else
                const Text(
                  'Không có thông tin chủ kho',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cài đặt'),
        content: const Text('Tính năng đang phát triển...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

// ============================ ADVANCED CONTROL SCREEN ============================

class AdvancedControlScreen extends StatefulWidget {
  final String warehouseName;
  final Map<String, dynamic> warehouseData;
  final String prefix;

  const AdvancedControlScreen({
    super.key,
    required this.warehouseName,
    required this.warehouseData,
    required this.prefix,
  });

  @override
  State<AdvancedControlScreen> createState() => _AdvancedControlScreenState();
}

class _AdvancedControlScreenState extends State<AdvancedControlScreen> {
  late DatabaseReference _db;
  bool _isLoading = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _lowTempController = TextEditingController();
  final TextEditingController _lowHumController = TextEditingController();
  final TextEditingController _highTempController = TextEditingController();
  final TextEditingController _highHumController = TextEditingController();

  String _selectedCountryCode = '+84';
  bool _showPassword = false;

  bool _lockState = false;
  bool _lightState = false;
  bool _childlockState = false;
  bool _alarmState = false;
  bool _autoState = false;
  bool _pirState = false;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    _loadCurrentSettings();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    final prefix = widget.prefix;

    _db.child('kho$prefix/lock$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _lockState = event.snapshot.value == true;
        });
      }
    });

    _db.child('kho$prefix/light$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _lightState = event.snapshot.value == true;
        });
      }
    });

    _db.child('kho$prefix/childlock$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _childlockState = event.snapshot.value == true;
        });
      }
    });

    _db.child('kho$prefix/alarm$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _alarmState = event.snapshot.value == true;
        });
      }
    });

    _db.child('kho$prefix/auto$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _autoState = event.snapshot.value == true;
        });
      }
    });

    _db.child('kho$prefix/pir$prefix').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _pirState = event.snapshot.value == true;
        });
      }
    });
  }

  void _loadCurrentSettings() {
    final data = widget.warehouseData;
    final prefix = widget.prefix;

    _lockState = data['lock$prefix'] == true;
    _lightState = data['light$prefix'] == true;
    _childlockState = data['childlock$prefix'] == true;
    _alarmState = data['alarm$prefix'] == true;
    _autoState = data['auto$prefix'] == true;
    _pirState = data['pir$prefix'] == true;

    final currentPhone = data['phone$prefix']?.toString() ?? '';
    if (currentPhone.isNotEmpty) {
      final cleanedPhone = currentPhone.replaceAll(' ', '');
      if (cleanedPhone.startsWith('+84') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+84';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+1') && cleanedPhone.length > 2) {
        _selectedCountryCode = '+1';
        _phoneController.text = cleanedPhone.substring(2);
      } else if (cleanedPhone.startsWith('+44') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+44';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+86') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+86';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+81') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+81';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+82') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+82';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+65') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+65';
        _phoneController.text = cleanedPhone.substring(3);
      } else if (cleanedPhone.startsWith('+60') && cleanedPhone.length > 3) {
        _selectedCountryCode = '+60';
        _phoneController.text = cleanedPhone.substring(3);
      } else {
        _selectedCountryCode = '+84';
        _phoneController.text =
            cleanedPhone.replaceFirst(RegExp(r'^\+\d+'), '');
      }
    } else {
      _selectedCountryCode = '+84';
      _phoneController.text = '';
    }

    _passwordController.text = data['pass$prefix']?.toString() ?? '';

    _lowTempController.text = data['lowtemp$prefix']?.toString() ?? '';
    _lowHumController.text = data['lowhum$prefix']?.toString() ?? '';
    _highTempController.text = data['hightemp$prefix']?.toString() ?? '';
    _highHumController.text = data['highhum$prefix']?.toString() ?? '';
  }

  Future<void> _toggleControl(String controlName, bool currentValue) async {
    setState(() => _isLoading = true);

    try {
      final newValue = !currentValue;
      await _db
          .child('kho${widget.prefix}/$controlName${widget.prefix}')
          .set(newValue);

      _updateLocalState(controlName, newValue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã ${newValue ? 'bật' : 'tắt'} ${_getControlName(controlName)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi điều khiển: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateLocalState(String controlName, bool value) {
    switch (controlName) {
      case 'lock':
        setState(() => _lockState = value);
        break;
      case 'light':
        setState(() => _lightState = value);
        break;
      case 'childlock':
        setState(() => _childlockState = value);
        break;
      case 'auto':
        setState(() => _autoState = value);
        break;
      case 'pir':
        break;
    }
  }

  Future<void> _updateSetting(String settingName, dynamic value) async {
    setState(() => _isLoading = true);

    try {
      await _db
          .child('kho${widget.prefix}/$settingName${widget.prefix}')
          .set(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật cài đặt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getControlName(String control) {
    switch (control) {
      case 'lock':
        return 'cửa kho';
      case 'light':
        return 'đèn';
      case 'childlock':
        return 'chế độ khóa an toàn';
      case 'auto':
        return 'chế độ tự động';
      default:
        return control;
    }
  }

  Widget _buildControlCard(String title, String controlName, bool currentValue,
      IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(currentValue ? 'ĐANG BẬT' : 'ĐANG TẮT'),
        trailing: Switch(
          value: currentValue,
          onChanged: _isLoading
              ? null
              : (value) => _toggleControl(controlName, currentValue),
          activeColor: color,
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      String title, bool currentValue, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(currentValue ? 'ĐANG BÁO ĐỘNG' : 'BÌNH THƯỜNG'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: currentValue ? Colors.red : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentValue ? 'CẢNH BÁO' : 'AN TOÀN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorDisplayCard(
      String title, bool currentValue, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
            currentValue ? 'PHÁT HIỆN CHUYỂN ĐỘNG' : 'KHÔNG CÓ CHUYỂN ĐỘNG'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: currentValue ? Colors.purple : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentValue ? 'CÓ NGƯỜI' : 'VẮNG',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt nâng cao - ${widget.warehouseName}'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điều khiển cơ bản',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildControlCard(
                      'Cửa Kho', 'lock', _lockState, Icons.lock, Colors.blue),
                  _buildControlCard('Đèn', 'light', _lightState,
                      Icons.lightbulb, Colors.amber),
                  _buildControlCard('Khóa An Toàn', 'childlock',
                      _childlockState, Icons.child_care, Colors.orange),
                  _buildStatusCard(
                      'Báo Động', _alarmState, Icons.warning, Colors.red),
                  _buildControlCard('Chế độ tự động', 'auto', _autoState,
                      Icons.auto_mode, Colors.green),
                  _buildSensorDisplayCard('Cảm biến chuyển động', _pirState,
                      Icons.sensors, _pirState ? Colors.purple : Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Thông tin hệ thống',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Số lần mở khóa thất bại',
                    '${widget.warehouseData['fail${widget.prefix}'] ?? 0} lần',
                    Icons.error_outline,
                  ),
                  _buildInfoCard(
                    'Số thẻ con đã đăng ký',
                    '${widget.warehouseData['childcard${widget.prefix}'] ?? '0'} thẻ',
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cài đặt cảnh báo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nhiệt độ thấp cảnh báo (°C)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _lowTempController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      signed: true, decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^-?\d*\.?\d*$')),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ví dụ: -10.5, 5.2',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final value = double.tryParse(
                                            _lowTempController.text);
                                        if (value != null) {
                                          _updateSetting('lowtemp', value);
                                        }
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Độ ẩm thấp cảnh báo (%)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _lowHumController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ví dụ: 30.5, 45.0',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final value = double.tryParse(
                                            _lowHumController.text);
                                        if (value != null) {
                                          _updateSetting('lowhum', value);
                                        }
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nhiệt độ cao cảnh báo (°C)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _highTempController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      signed: true, decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^-?\d*\.?\d*$')),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ví dụ: 25.5, 30.0, -5.2',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final value = double.tryParse(
                                            _highTempController.text);
                                        if (value != null) {
                                          _updateSetting('hightemp', value);
                                        }
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Độ ẩm cao cảnh báo (%)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _highHumController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ví dụ: 80.5, 95.0',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final value = double.tryParse(
                                            _highHumController.text);
                                        if (value != null) {
                                          _updateSetting('highhum', value);
                                        }
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cài đặt bảo mật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số điện thoại cảnh báo (Allowed Phone)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              DropdownButton<String>(
                                value: _selectedCountryCode,
                                items: const [
                                  DropdownMenuItem(
                                      value: '+84', child: Text('+84 Vietnam')),
                                  DropdownMenuItem(
                                      value: '+1', child: Text('+1 USA')),
                                  DropdownMenuItem(
                                      value: '+44', child: Text('+44 UK')),
                                  DropdownMenuItem(
                                      value: '+86', child: Text('+86 China')),
                                  DropdownMenuItem(
                                      value: '+81', child: Text('+81 Japan')),
                                  DropdownMenuItem(
                                      value: '+82', child: Text('+82 Korea')),
                                  DropdownMenuItem(
                                      value: '+65',
                                      child: Text('+65 Singapore')),
                                  DropdownMenuItem(
                                      value: '+60',
                                      child: Text('+60 Malaysia')),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedCountryCode = value!);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: 'Số điện thoại',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final cleanedPhone = _phoneController
                                            .text
                                            .trim()
                                            .replaceAll(' ', '');
                                        final phoneNumber =
                                            '$_selectedCountryCode$cleanedPhone';
                                        _updateSetting('phone', phoneNumber);
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Số điện thoại này sẽ nhận SMS cảnh báo từ hệ thống',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mật khẩu phần cứng'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Nhập 6 số mật khẩu',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(_showPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        if (_passwordController.text.length ==
                                            6) {
                                          _updateSetting(
                                              'pass', _passwordController.text);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Mật khẩu phải có đúng 6 số')),
                                          );
                                        }
                                      },
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mật khẩu 6 số để mở khóa bằng keypad',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ============================ PRODUCT MANAGEMENT SCREEN ============================

class ProductManagementScreen extends StatefulWidget {
  final String warehouseName;
  final String warehousePrefix;
  final Map<String, dynamic> currentProducts;
  final String userId;
  final String userName;

  const ProductManagementScreen({
    super.key,
    required this.warehouseName,
    required this.warehousePrefix,
    required this.currentProducts,
    required this.userId,
    required this.userName,
  });

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  late DatabaseReference _db;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    _loadProducts();
  }

  void _loadProducts() {
    final products = <Map<String, dynamic>>[];

    for (final entry in widget.currentProducts.entries) {
      final product = _convertData(entry.value);
      product['id'] = entry.key;
      products.add(product);
    }

    products.sort((a, b) {
      try {
        final aDate = a['expiry_date']?.toString() ?? '';
        final bDate = b['expiry_date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      } catch (_) {
        return 0;
      }
    });

    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _convertData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      final result = <String, dynamic>{};
      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          result[key.toString()] = _convertData(value);
        } else {
          result[key.toString()] = value;
        }
      }
      return result;
    }
    return {};
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        warehousePrefix: widget.warehousePrefix,
        userId: widget.userId,
        userName: widget.userName,
        onProductAdded: () {
          Navigator.pop(context);
          _refreshProducts();
        },
      ),
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => EditProductDialog(
        product: product,
        warehousePrefix: widget.warehousePrefix,
        userId: widget.userId,
        userName: widget.userName,
        onProductUpdated: () {
          Navigator.pop(context);
          _refreshProducts();
        },
      ),
    );
  }

  void _deleteProduct(String productId, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hàng hóa'),
        content: Text('Bạn có chắc muốn xóa "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final path = 'products/kho${widget.warehousePrefix}/$productId';
                print('🗑️ Xóa hàng hóa: $path');

                await _db.child(path).remove();

                // Xóa ngay trong danh sách local để UI cập nhật
                setState(() {
                  _products.removeWhere((p) => p['id'] == productId);
                });

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Đã xóa "$productName"')),
                  );
                }
              } catch (e) {
                print('❌ Lỗi xóa: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Lỗi khi xóa: $e')),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProducts() async {
    setState(() => _isLoading = true);
    try {
      final path = 'products/kho${widget.warehousePrefix}';
      print('🔄 Refreshing from path: $path');

      final snapshot = await _db.child(path).get();

      if (snapshot.exists) {
        final products = _convertData(snapshot.value);
        _loadProductsFromMap(products);
      } else {
        setState(() {
          _products = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Lỗi refresh: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadProductsFromMap(Map<String, dynamic> products) {
    final productList = <Map<String, dynamic>>[];

    for (final entry in products.entries) {
      final product = _convertData(entry.value);
      product['id'] = entry.key;
      productList.add(product);
    }

    productList.sort((a, b) {
      try {
        final aDate = a['expiry_date']?.toString() ?? '';
        final bDate = b['expiry_date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      } catch (_) {
        return 0;
      }
    });

    setState(() {
      _products = productList;
      _isLoading = false;
    });
  }

  void _showQRCodeDialog(Map<String, dynamic> product) async {
    final qrData = QRCodeService.generateQRData(product);
    final qrImageBytes = await QRCodeService.generateQRImage(qrData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'QR Code - ${product['name']}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (qrImageBytes != null)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(
                    qrImageBytes,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Không thể tạo QR code',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Quét mã QR để xem thông tin hàng hóa',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  qrData,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () => _downloadQRCode(product),
            child: const Text('Chia sẻ QR'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(Map<String, dynamic> product) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final qrData = QRCodeService.generateQRData(product);
      final qrImageBytes = await QRCodeService.generateQRImage(qrData);

      if (qrImageBytes != null) {
        final productName = product['name']
                ?.toString()
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ??
            'product';
        final fileName = 'QR_${productName}.png';

        final success = await QRCodeService.shareQRCode(qrImageBytes, fileName);

        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Đang chia sẻ QR code của "${product['name']}"'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Không thể chia sẻ QR code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi tạo QR code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý hàng hóa - ${widget.warehouseName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Chưa có hàng hóa nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Nhấn nút + để thêm hàng hóa mới',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductItem(product);
                  },
                ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final today = DateTime.now();
    int daysLeft = 0;
    Color expiryColor = Colors.green;
    String expiryText = '';

    final expiry = product['expiry_date'];
    if (expiry != null) {
      try {
        final expiryDate = DateTime.parse(expiry.toString());
        daysLeft = expiryDate.difference(today).inDays;

        if (daysLeft < 0) {
          expiryColor = Colors.red;
          expiryText = 'ĐÃ HẾT HẠN';
        } else if (daysLeft <= 7) {
          expiryColor = Colors.orange;
          expiryText = 'Còn $daysLeft ngày';
        } else {
          expiryText = 'Còn $daysLeft ngày';
        }
      } catch (_) {
        expiryColor = Colors.grey;
        expiryText = 'Không xác định';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.inventory_2, color: Colors.blue[700]),
        ),
        title: Text(
          product['name']?.toString() ?? 'Không có tên',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Số lượng: ${product['quantity']} ${product['unit']}'),
            if (product['price'] != null)
              Text('Giá: ${_formatPrice(product['price'])}'),
            if (product['import_date'] != null)
              Text('Ngày nhập: ${product['import_date']}'),
            Text('HSD: ${product['expiry_date']}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: expiryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: expiryColor),
              ),
              child: Text(
                expiryText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: expiryColor,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.blue, size: 24),
              onPressed: () {
                _showQRCodeDialog(product);
              },
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.green, size: 24),
              onPressed: () {
                _downloadQRCode(product);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editProduct(product);
                } else if (value == 'delete') {
                  _deleteProduct(
                      product['id'], product['name']?.toString() ?? 'Hàng hóa');
                } else if (value == 'view_qr') {
                  _showQRCodeDialog(product);
                } else if (value == 'share_qr') {
                  _downloadQRCode(product);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                const PopupMenuItem(
                    value: 'view_qr', child: Text('Xem QR Code')),
                const PopupMenuItem(
                    value: 'share_qr', child: Text('Chia sẻ QR Code')),
                const PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0 đ';
    final number = price is String ? int.tryParse(price) : price.toInt();
    return '${number?.toString() ?? '0'} đ';
  }
}

// ============================ PRODUCT SEARCH SCREEN ============================

class ProductSearchScreen extends StatefulWidget {
  final Map<String, dynamic> productsData;
  final bool accessKho1;
  final bool accessKho2;

  const ProductSearchScreen({
    super.key,
    required this.productsData,
    required this.accessKho1,
    required this.accessKho2,
  });

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _allProducts = [];
  String _selectedWarehouse = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadAllProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadAllProducts() {
    final allProducts = <Map<String, dynamic>>[];

    if (widget.accessKho1) {
      final kho1Products = widget.productsData['kho1'] ?? {};
      for (final entry in kho1Products.entries) {
        final product = _convertData(entry.value);
        product['id'] = entry.key;
        product['warehouse'] = 'Kho 1';
        product['warehouse_key'] = 'kho1';
        allProducts.add(product);
      }
    }

    if (widget.accessKho2) {
      final kho2Products = widget.productsData['kho2'] ?? {};
      for (final entry in kho2Products.entries) {
        final product = _convertData(entry.value);
        product['id'] = entry.key;
        product['warehouse'] = 'Kho 2';
        product['warehouse_key'] = 'kho2';
        allProducts.add(product);
      }
    }

    setState(() {
      _allProducts = allProducts;
      _filteredProducts = allProducts;
    });
  }

  Map<String, dynamic> _convertData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      final result = <String, dynamic>{};
      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          result[key.toString()] = _convertData(value);
        } else {
          result[key.toString()] = value;
        }
      }
      return result;
    }
    return {};
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    _filterProducts(query, _selectedWarehouse);
  }

  void _filterProducts(String query, String warehouse) {
    List<Map<String, dynamic>> filtered = _allProducts;

    // Lọc theo kho
    if (warehouse != 'Tất cả') {
      filtered = filtered.where((product) {
        return product['warehouse'] == warehouse;
      }).toList();
    }

    // Lọc theo từ khóa
    if (query.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final category = product['category']?.toString().toLowerCase() ?? '';
        final supplier = product['supplier']?.toString().toLowerCase() ?? '';
        final id = product['id']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            category.contains(query) ||
            supplier.contains(query) ||
            id.contains(query);
      }).toList();
    }

    setState(() {
      _filteredProducts = filtered;
      _selectedWarehouse = warehouse;
    });
  }

  List<String> _getWarehouseOptions() {
    final options = <String>['Tất cả'];
    if (widget.accessKho1) options.add('Kho 1');
    if (widget.accessKho2) options.add('Kho 2');
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm hàng hóa'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, mã, nhà cung cấp...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterProducts('', _selectedWarehouse);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Warehouse filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _getWarehouseOptions().map((warehouse) {
                      final isSelected = _selectedWarehouse == warehouse;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(warehouse),
                          selected: isSelected,
                          onSelected: (_) {
                            _filterProducts(_searchController.text, warehouse);
                          },
                          backgroundColor:
                              isSelected ? Colors.blue : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tìm thấy ${_filteredProducts.length} hàng hóa',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Không có hàng hóa nào'
                              : 'Không tìm thấy hàng hóa phù hợp',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductItem(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final today = DateTime.now();
    int daysLeft = 0;
    Color expiryColor = Colors.green;

    final expiry = product['expiry_date'];
    if (expiry != null) {
      try {
        final expiryDate = DateTime.parse(expiry.toString());
        daysLeft = expiryDate.difference(today).inDays;
        if (daysLeft < 0) {
          expiryColor = Colors.red;
        } else if (daysLeft <= 7) {
          expiryColor = Colors.orange;
        }
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2, color: Colors.blue),
        ),
        title: Text(
          product['name']?.toString() ?? 'Không có tên',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Kho: ${product['warehouse']}'),
            Text('Số lượng: ${product['quantity']} ${product['unit']}'),
            Text('HSD: ${product['expiry_date']}'),
            const SizedBox(height: 4),
            if (expiry != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expiryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: expiryColor),
                ),
                child: Text(
                  daysLeft < 0 ? 'ĐÃ HẾT HẠN' : 'Còn $daysLeft ngày',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: expiryColor,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Show product details
          _showProductDetails(product);
        },
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['name']?.toString() ?? 'Chi tiết hàng hóa'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Mã SP:', product['id']),
              _buildDetailRow('Kho:', product['warehouse']),
              _buildDetailRow('Danh mục:', product['category']),
              _buildDetailRow(
                  'Số lượng:', '${product['quantity']} ${product['unit']}'),
              _buildDetailRow('Giá:', '${product['price']} đ'),
              _buildDetailRow('Nhà cung cấp:', product['supplier']),
              _buildDetailRow('Ngày nhập:', product['import_date']),
              _buildDetailRow('Hạn sử dụng:', product['expiry_date']),
              const SizedBox(height: 16),
              const Text(
                'Lưu ý: Chỉ có thể chỉnh sửa/sửa từ màn hình quản lý hàng hóa của từng kho',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value ?? 'Không có'),
          ),
        ],
      ),
    );
  }
}

// ============================ ADD PRODUCT DIALOG ============================

class AddProductDialog extends StatefulWidget {
  final String warehousePrefix;
  final String userId;
  final String userName;
  final VoidCallback onProductAdded;

  const AddProductDialog({
    super.key,
    required this.warehousePrefix,
    required this.userId,
    required this.userName,
    required this.onProductAdded,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late DatabaseReference _db;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _importDateController = TextEditingController();

  String _selectedCategory = 'Ngũ cốc';
  String _selectedUnit = 'kg';
  final List<String> _categories = [
    'Ngũ cốc',
    'Gia vị',
    'Thịt',
    'Hải sản',
    'Rau củ',
    'Trái cây',
    'Đồ uống',
    'Sữa',
    'Đồ khô',
    'Khác'
  ];
  final List<String> _units = [
    'kg',
    'g',
    'l',
    'ml',
    'hộp',
    'chai',
    'túi',
    'lon',
    'gói',
    'quả',
    'cái'
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    final now = DateTime.now();
    _importDateController.text = _formatDate(now);
    _expiryDateController.text = _formatDate(now.add(const Duration(days: 30)));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(
      TextEditingController controller, DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = _formatDate(picked);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final lastIdSnapshot = await _db
          .child('system/last_product_id_${widget.warehousePrefix}')
          .get();
      int lastId = 0;
      if (lastIdSnapshot.exists) {
        final value = lastIdSnapshot.value;
        if (value is int) {
          lastId = value;
        } else if (value is String) {
          lastId = int.tryParse(value) ?? 0;
        }
      }

      final newId = lastId + 1;
      final productId =
          'TP${widget.warehousePrefix}${newId.toString().padLeft(3, '0')}';

      final productData = {
        'id': productId,
        'name': _nameController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'price': int.tryParse(_priceController.text) ?? 0,
        'unit': _selectedUnit,
        'category': _selectedCategory,
        'supplier': _supplierController.text,
        'import_date': _importDateController.text,
        'expiry_date': _expiryDateController.text,
        'created_by': widget.userName,
        'created_date': _formatDate(DateTime.now()),
      };

      await _db
          .child('products/kho${widget.warehousePrefix}/$productId')
          .set(productData);
      await _db
          .child('system/last_product_id_${widget.warehousePrefix}')
          .set(newId);

      if (mounted) {
        Navigator.pop(context);
        widget.onProductAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm hàng hóa thành công')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi Firebase: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm hàng hóa: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm hàng hóa mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên hàng hóa'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Nhập tên hàng hóa' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value?.isEmpty == true ? 'Nhập số lượng' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Đơn vị'),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUnit = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Nhập giá' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _importDateController,
                decoration: const InputDecoration(
                  labelText: 'Ngày nhập kho',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_importDateController, DateTime.now()),
                validator: (value) =>
                    value?.isEmpty == true ? 'Chọn ngày nhập kho' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Hạn sử dụng',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_expiryDateController,
                    DateTime.now().add(const Duration(days: 30))),
                validator: (value) =>
                    value?.isEmpty == true ? 'Chọn hạn sử dụng' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator())
              : const Text('Thêm'),
        ),
      ],
    );
  }
}

// ============================ EDIT PRODUCT DIALOG ============================

class EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final String warehousePrefix;
  final String userId;
  final String userName;
  final VoidCallback onProductUpdated;

  const EditProductDialog({
    super.key,
    required this.product,
    required this.warehousePrefix,
    required this.userId,
    required this.userName,
    required this.onProductUpdated,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late DatabaseReference _db;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _importDateController = TextEditingController();

  String _selectedCategory = 'Ngũ cốc';
  String _selectedUnit = 'kg';
  final List<String> _categories = [
    'Ngũ cốc',
    'Gia vị',
    'Thịt',
    'Hải sản',
    'Rau củ',
    'Trái cây',
    'Đồ uống',
    'Sữa',
    'Đồ khô',
    'Khác'
  ];
  final List<String> _units = [
    'kg',
    'g',
    'l',
    'ml',
    'hộp',
    'chai',
    'túi',
    'lon',
    'gói',
    'quả',
    'cái'
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('UserApp')).ref();
    _loadProductData();
  }

  void _loadProductData() {
    final product = widget.product;
    _nameController.text = product['name']?.toString() ?? '';
    _quantityController.text = product['quantity']?.toString() ?? '';
    _priceController.text = product['price']?.toString() ?? '';
    _selectedUnit = product['unit']?.toString() ?? 'kg';
    _selectedCategory = product['category']?.toString() ?? 'Ngũ cốc';
    _supplierController.text = product['supplier']?.toString() ?? '';
    _importDateController.text = product['import_date']?.toString() ?? '';
    _expiryDateController.text = product['expiry_date']?.toString() ?? '';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(
      TextEditingController controller, DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = _formatDate(picked);
      });
    }
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'name': _nameController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'price': int.tryParse(_priceController.text) ?? 0,
        'unit': _selectedUnit,
        'category': _selectedCategory,
        'supplier': _supplierController.text,
        'import_date': _importDateController.text,
        'expiry_date': _expiryDateController.text,
        'updated_by': widget.userName,
        'updated_date': _formatDate(DateTime.now()),
      };

      await _db
          .child(
              'products/kho${widget.warehousePrefix}/${widget.product['id']}')
          .update(productData);

      if (mounted) {
        Navigator.pop(context);
        widget.onProductUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật hàng hóa thành công')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi Firebase: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật hàng hóa: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa hàng hóa'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên hàng hóa'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Nhập tên hàng hóa' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value?.isEmpty == true ? 'Nhập số lượng' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Đơn vị'),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUnit = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Nhập giá' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _importDateController,
                decoration: const InputDecoration(
                  labelText: 'Ngày nhập kho',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_importDateController, DateTime.now()),
                validator: (value) =>
                    value?.isEmpty == true ? 'Chọn ngày nhập kho' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Hạn sử dụng',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_expiryDateController,
                    DateTime.now().add(const Duration(days: 30))),
                validator: (value) =>
                    value?.isEmpty == true ? 'Chọn hạn sử dụng' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateProduct,
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator())
              : const Text('Cập nhật'),
        ),
      ],
    );
  }
}

// ============================ QR CODE SERVICE ============================

class QRCodeService {
  static String generateQRData(Map<String, dynamic> product) {
    final unitPrice = int.tryParse(product['price']?.toString() ?? '0') ?? 0;

    final data = {
      'Tên SP': product['name']?.toString() ?? 'Chưa có',
      'Danh mục': product['category']?.toString() ?? 'Chưa có',
      'Nhà cung cấp': product['supplier']?.toString() ?? 'Chưa có',
      'Đơn vị': product['unit']?.toString() ?? 'Chưa có',
      'Đơn giá': '${_formatPriceForQR(unitPrice)}',
      'Ngày nhập': product['import_date']?.toString() ?? 'Chưa có',
      'Hạn sử dụng': product['expiry_date']?.toString() ?? 'Chưa có',
      'Mã SP': product['id']?.toString() ?? 'Chưa có',
    };
    return data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  static String _formatPriceForQR(int price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )} VNĐ';
  }

  static Future<Uint8List?> generateQRImage(String data) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = 200.0;

      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size, size), backgroundPaint);

      qrPainter.paint(canvas, Size(size, size));

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error generating QR image: $e');
      return null;
    }
  }

  static Future<bool> shareQRCode(
      Uint8List qrImageBytes, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = await writeToFile(qrImageBytes, filePath);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code hàng hóa - Quét để xem thông tin chi tiết',
      );
      return true;
    } catch (e) {
      print('Error sharing QR code: $e');
      return false;
    }
  }

  static Future<File> writeToFile(Uint8List data, String path) async {
    final file = File(path);
    await file.writeAsBytes(data);
    return file;
  }
}
