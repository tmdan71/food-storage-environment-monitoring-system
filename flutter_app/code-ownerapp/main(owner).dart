// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// === Firebase configuration ===
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyDWRu3oHxEEQUocBSd5upvmXEinS-KzwTQ",
  appId: "1:308397605369:android:e8b79cc67ccc92e602fd28",
  messagingSenderId: "308397605369",
  projectId: "hethongkho-39e4f",
  databaseURL:
      "https://hethongkho-39e4f-default-rtdb.asia-southeast1.firebasedatabase.app",
  storageBucket: "hethongkho-39e4f.appspot.com",
);

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// === MAIN - ĐƠN GIẢN ===
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Bắt đầu khởi tạo ứng dụng OWNER (hethongkho.spkt)...');

  try {
    await _initializeFirebase();
    await _initializeNotifications();
    print('🎉 Ứng dụng OWNER khởi tạo thành công');
  } catch (e, stack) {
    print('🔴 Lỗi khởi tạo ứng dụng OWNER: $e');
    print(stack);
  }

  runApp(const OwnerApp());
}

/// === CÁC HÀM KHỞI TẠO ===
Future<void> _initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);
  print('🔔 Đã khởi tạo local notifications');
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      print('🟡 Đang khởi tạo Firebase cho OwnerApp...');
      await Firebase.initializeApp(
        name: 'OwnerApp',
        options: firebaseConfig,
      );
      print('🟢 Firebase OwnerApp khởi tạo thành công');
    } else {
      print('🟢 Sử dụng Firebase OwnerApp instance đã tồn tại');
      Firebase.app('OwnerApp');
    }
  } catch (e) {
    print('🔴 Lỗi khởi tạo Firebase OwnerApp: $e');
    try {
      await Firebase.initializeApp();
      print('🟢 Firebase initialized without name');
    } catch (e2) {
      print('🔴 Firebase fallback also failed: $e2');
    }
  }
}

/// === HÀM HIỂN THỊ THÔNG BÁO ===
Future<void> _showNotification(String title, String body) async {
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
}

/// === GỬI CẢNH BÁO (LOCAL ONLY) ===
Future<void> _sendLocalAlert(String title, String body, String type) async {
  print('🚨 Gửi cảnh báo local: $title - $body - Type: $type');

  // 1. Hiển thị notification local
  await _showNotification(title, body);

  // 2. Lưu log vào Firebase (tuỳ chọn)
  try {
    final db =
        FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
    await db.child('alert_logs').push().set({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': ServerValue.timestamp,
      'sent_via_fcm': false,
      'sent_by': 'owner_app',
    });
    print('📝 Đã lưu log cảnh báo');
  } catch (e) {
    print('⚠️ Lỗi lưu log cảnh báo: $e');
  }
}

/// === OWNER APP ===
class OwnerApp extends StatelessWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chủ Kho Thực Phẩm - hethongkho',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// === DASHBOARD SCREEN ===
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late DatabaseReference _db;
  Map<String, dynamic> _warehouseData = {};
  Map<String, dynamic> _usersData = {};
  Map<String, dynamic> _productsData = {};
  Map<String, dynamic> _rentalSettings = {};
  Map<String, dynamic> _ownerInfo = {};
  bool _isLoading = true;

  Timer? _rentalCheckTimer;
  Timer? _environmentCheckTimer;
  Timer? _cleanupTimer;

  final Map<String, DateTime> _lastRentalWarning = {};
  final Map<String, DateTime> _lastEnvironmentWarning = {};

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
    print('📱 DashboardScreen OwnerApp initState');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadAll();
      _setupRealtime();
      _startRentalTimer();
      _startEnvironmentTimer();
      _startCleanupTimer();
      await _cleanupOldAlerts();
    } catch (e) {
      print('🔴 Lỗi khởi tạo Dashboard Owner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _rentalCheckTimer?.cancel();
    _environmentCheckTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

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

  // ---------- Load data ----------
  Future<void> _loadAll() async {
    try {
      setState(() => _isLoading = true);

      final s1 = await _db.child('kho1').get();
      final s2 = await _db.child('kho2').get();
      final users = await _db.child('owner/users').get();
      final p1 = await _db.child('products/kho1').get();
      final p2 = await _db.child('products/kho2').get();
      final settings = await _db.child('system/rental_settings').get();
      final ownerInfo = await _db.child('owner_info').get();

      setState(() {
        _warehouseData = {'kho1': _asMap(s1.value), 'kho2': _asMap(s2.value)};
        _usersData = _asMap(users.value);
        _productsData = {'kho1': _asMap(p1.value), 'kho2': _asMap(p2.value)};
        _rentalSettings = (settings.value is Map)
            ? Map<String, dynamic>.from(settings.value as Map)
            : {'warning_days': 7, 'auto_lock_after_expiry': true};
        _ownerInfo = _asMap(ownerInfo.value);
        _isLoading = false;
      });

      await _checkRentalExpiry();
      _checkEnvironmentAlerts();
    } catch (e) {
      setState(() => _isLoading = false);
      print('🔴 Lỗi load dữ liệu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _setupRealtime() {
    _db.child('kho1').onValue.listen((ev) {
      if (mounted) {
        setState(() => _warehouseData['kho1'] = _asMap(ev.snapshot.value));
      }
    });
    _db.child('kho2').onValue.listen((ev) {
      if (mounted) {
        setState(() => _warehouseData['kho2'] = _asMap(ev.snapshot.value));
      }
    });
    _db.child('owner/users').onValue.listen((ev) {
      if (mounted) setState(() => _usersData = _asMap(ev.snapshot.value));
    });
    _db.child('products').onValue.listen((ev) {
      if (mounted) {
        final all = _asMap(ev.snapshot.value);
        setState(() {
          _productsData['kho1'] = _asMap(all['kho1']);
          _productsData['kho2'] = _asMap(all['kho2']);
        });
      }
    });
    _db.child('owner_info').onValue.listen((ev) {
      if (mounted) setState(() => _ownerInfo = _asMap(ev.snapshot.value));
    });
  }

  // ---------- Local Notifications ----------
  Future<void> _showLocalNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'default',
      'General',
      importance: Importance.high,
      priority: Priority.high,
    );
    const detail = NotificationDetails(android: android);
    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      detail,
    );
  }

  // ---------- Rental checks (12 tiếng) ----------
  Future<void> _checkRentalExpiry() async {
    final today = DateTime.now();
    final warningDays = (_rentalSettings['warning_days'] ?? 7) as int;

    for (final entry in _usersData.entries) {
      final uid = entry.key;
      final user = _asMap(entry.value);
      if ((user['status'] ?? '') != 'active') continue;

      final endStr = (user['end_date'] ?? '') as String;
      try {
        final end = DateFormat('yyyy-MM-dd').parse(endStr);
        final daysLeft = end.difference(today).inDays;

        final lastWarning = _lastRentalWarning[uid];
        if (lastWarning != null &&
            DateTime.now().difference(lastWarning).inHours < 12) {
          continue;
        }

        if (daysLeft <= warningDays && daysLeft >= 0) {
          final title = 'Thuê bao sắp hết hạn';
          final body =
              '${user['full_name'] ?? 'Người dùng'} còn $daysLeft ngày';

          await _showLocalNotification(title, body);
          await _sendLocalAlert(title, body, 'rental_warning');
          _lastRentalWarning[uid] = DateTime.now();
        }
        if (daysLeft < 0) {
          await _handleExpiredRental(uid, user);
          final title = 'Thuê bao đã hết hạn';
          final body =
              '${user['full_name'] ?? 'Người dùng'} đã hết hạn. Đã khóa tài khoản.';

          await _showLocalNotification(title, body);
          await _sendLocalAlert(title, body, 'rental_expired');
          _lastRentalWarning[uid] = DateTime.now();
        }
      } catch (_) {}
    }
  }

  Future<void> _handleExpiredRental(
      String uid, Map<String, dynamic> user) async {
    if (_rentalSettings['auto_lock_after_expiry'] == true) {
      await _db.child('owner/users/$uid/status').set('expired');
    }
  }

  // ---------- Environment checks (30 giây) ----------
  void _checkEnvironmentAlerts() {
    _checkSingleWarehouseAlert('kho1', _warehouseData['kho1']);
    _checkSingleWarehouseAlert('kho2', _warehouseData['kho2']);
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

  // ---------- Stats ----------
  Map<String, dynamic> _calculateStats() {
    final activeUsers = _usersData.entries
        .where((e) => (_asMap(e.value)['status'] ?? '') == 'active')
        .length;

    final totalProducts = {
      'kho1': (_productsData['kho1'] as Map?)?.length ?? 0,
      'kho2': (_productsData['kho2'] as Map?)?.length ?? 0,
    };

    final today = DateTime.now();
    final warningDays = (_rentalSettings['warning_days'] ?? 7) as int;

    final expiring = _usersData.entries.where((e) {
      final u = _asMap(e.value);
      if ((u['status'] ?? '') != 'active') return false;
      try {
        final end = DateFormat('yyyy-MM-dd').parse(u['end_date'] as String);
        final d = end.difference(today).inDays;
        return d <= warningDays && d >= 0;
      } catch (_) {
        return false;
      }
    }).length;

    final expired = _usersData.entries.where((e) {
      final u = _asMap(e.value);
      if ((u['status'] ?? '') != 'active') return false;
      try {
        final end = DateFormat('yyyy-MM-dd').parse(u['end_date'] as String);
        return end.isBefore(today);
      } catch (_) {
        return false;
      }
    }).length;

    return {
      'activeUsers': activeUsers,
      'totalProducts': totalProducts,
      'expiringRentals': expiring,
      'expiredRentals': expired,
    };
  }

  // ---------- UI builders ----------
  Widget _buildStatItem(String label, String value) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    final totalSP = (stats['totalProducts']?['kho1'] ?? 0) +
        (stats['totalProducts']?['kho2'] ?? 0);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 THỐNG KÊ HỆ THỐNG',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('👥 Users', '${stats['activeUsers'] ?? 0}'),
                _buildStatItem('📦 Tổng SP', '$totalSP'),
                _buildStatItem(
                    '🏭 Kho 1', '${stats['totalProducts']?['kho1'] ?? 0}'),
                _buildStatItem(
                    '🏭 Kho 2', '${stats['totalProducts']?['kho2'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 8),
            if ((stats['expiringRentals'] ?? 0) > 0 ||
                (stats['expiredRentals'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        '⏳ Sắp hết hạn', '${stats['expiringRentals'] ?? 0}'),
                    _buildStatItem(
                        '❌ Đã hết hạn', '${stats['expiredRentals'] ?? 0}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalAlertsCard(Map<String, dynamic> stats) {
    if ((stats['expiringRentals'] ?? 0) == 0 &&
        (stats['expiredRentals'] ?? 0) == 0) return const SizedBox();
    final expired = (stats['expiredRentals'] ?? 0) > 0;
    return Card(
      color: expired ? Colors.red[50] : Colors.orange[50],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              expired ? Icons.error : Icons.warning,
              color: expired ? Colors.red : Colors.orange[800],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expired ? '❌ THUÊ BAO HẾT HẠN' : '⚠️ THUÊ BAO SẮP HẾT HẠN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: expired ? Colors.red : Colors.orange[800],
                    ),
                  ),
                  if ((stats['expiringRentals'] ?? 0) > 0)
                    Text('${stats['expiringRentals']} thuê bao sắp hết hạn'),
                  if ((stats['expiredRentals'] ?? 0) > 0)
                    Text('${stats['expiredRentals']} thuê bao đã hết hạn'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showRentalSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '👤 THÔNG TIN CHỦ KHO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _showOwnerInfoDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_ownerInfo.isEmpty)
              const Text('Chưa có thông tin chủ kho',
                  style: TextStyle(color: Colors.grey))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_ownerInfo['name'] != null)
                    Text('👤 Họ tên: ${_ownerInfo['name']}'),
                  if (_ownerInfo['phone'] != null)
                    Text('📞 SĐT: ${_ownerInfo['phone']}'),
                  if (_ownerInfo['email'] != null)
                    Text('📧 Email: ${_ownerInfo['email']}'),
                  if (_ownerInfo['address'] != null)
                    Text('🏠 Địa chỉ: ${_ownerInfo['address']}'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseItem(String name, dynamic data, int productCount) {
    final map = _asMap(data);
    final prefix = (name == 'KHO 1') ? '1' : '2';
    if (map.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Đang tải...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final currentTemp =
        double.tryParse(map['temp$prefix']?.toString() ?? '0') ?? 0;
    final currentHum =
        double.tryParse(map['hum$prefix']?.toString() ?? '0') ?? 0;
    final highTemp =
        double.tryParse(map['hightemp$prefix']?.toString() ?? '0') ?? 0;
    final highHum =
        double.tryParse(map['highhum$prefix']?.toString() ?? '0') ?? 0;
    final lowTemp =
        double.tryParse(map['lowtemp$prefix']?.toString() ?? '0') ?? 0;
    final lowHum =
        double.tryParse(map['lowhum$prefix']?.toString() ?? '0') ?? 0;

    final tempHighWarning = currentTemp >= highTemp;
    final tempLowWarning = currentTemp <= lowTemp;
    final humHighWarning = currentHum >= highHum;
    final humLowWarning = currentHum <= lowHum;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.thermostat,
                  size: 16,
                  color: tempHighWarning
                      ? Colors.red
                      : (tempLowWarning ? Colors.blue : Colors.red)),
              const SizedBox(width: 4),
              Text('${map['temp$prefix'] ?? 'N/A'}°C',
                  style: TextStyle(
                      color: tempHighWarning
                          ? Colors.red
                          : (tempLowWarning ? Colors.blue : Colors.black),
                      fontWeight: tempHighWarning || tempLowWarning
                          ? FontWeight.bold
                          : FontWeight.normal)),
              const SizedBox(width: 8),
              if (tempHighWarning)
                Text(
                  '⚠️ CAO',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              if (tempLowWarning)
                Text(
                  '⚠️ THẤP',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              'Ngưỡng: Cao ${map['hightemp$prefix'] ?? 'N/A'}°C | Thấp ${map['lowtemp$prefix'] ?? 'N/A'}°C',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.water_drop,
                  size: 16,
                  color: humHighWarning
                      ? Colors.red
                      : (humLowWarning ? Colors.blue : Colors.blue)),
              const SizedBox(width: 4),
              Text('${map['hum$prefix'] ?? 'N/A'}%',
                  style: TextStyle(
                      color: humHighWarning
                          ? Colors.red
                          : (humLowWarning ? Colors.blue : Colors.black),
                      fontWeight: humHighWarning || humLowWarning
                          ? FontWeight.bold
                          : FontWeight.normal)),
              const SizedBox(width: 8),
              if (humHighWarning)
                Text(
                  '⚠️ CAO',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              if (humLowWarning)
                Text(
                  '⚠️ THẤP',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              'Ngưỡng: Cao ${map['highhum$prefix'] ?? 'N/A'}% | Thấp ${map['lowhum$prefix'] ?? 'N/A'}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon((map['lock$prefix'] == true) ? Icons.lock_open : Icons.lock,
                  size: 16,
                  color:
                      (map['lock$prefix'] == true) ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text((map['lock$prefix'] == true) ? 'Mở' : 'Đóng'),
              const SizedBox(width: 16),
              const Icon(Icons.inventory_2, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text('$productCount sản phẩm'),
              const SizedBox(width: 16),
              Icon(Icons.lightbulb,
                  size: 16,
                  color: (map['light$prefix'] == true)
                      ? Colors.yellow[700]
                      : Colors.grey),
              const SizedBox(width: 4),
              Text((map['light$prefix'] == true) ? 'Đèn bật' : 'Đèn tắt'),
            ],
          ),
          if (map['alarm$prefix'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('🚨 BÁO ĐỘNG',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarehouseStatus() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏭 TRẠNG THÁI KHO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildWarehouseItem(
              'KHO 1',
              _warehouseData['kho1'],
              (_productsData['kho1'] as Map?)?.length ?? 0,
            ),
            const SizedBox(height: 12),
            _buildWarehouseItem(
              'KHO 2',
              _warehouseData['kho2'],
              (_productsData['kho2'] as Map?)?.length ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection() {
    if (_usersData.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Chưa có người dùng nào',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
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
                const Text(
                  '👥 NGƯỜI THUÊ KHO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                    onPressed: _showAddUser, child: const Text('+ Thêm user')),
              ],
            ),
            const SizedBox(height: 12),
            ..._usersData.entries.map((e) {
              final id = e.key;
              final user = _asMap(e.value);
              return _buildUserItem(id, user);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(String uid, Map<String, dynamic> u) {
    final today = DateTime.now();
    int daysLeft = 0;
    try {
      final end = DateFormat('yyyy-MM-dd').parse(
          u['end_date'] as String? ?? DateFormat('yyyy-MM-dd').format(today));
      daysLeft = end.difference(today).inDays;
    } catch (_) {
      daysLeft = 0;
    }

    Color statusColor = Colors.green;
    String statusText = 'Đang hoạt động';
    final status = (u['status'] ?? '') as String;
    if (status == 'expired') {
      statusColor = Colors.red;
      statusText = 'Đã hết hạn';
    } else if (daysLeft <= 7 && daysLeft >= 0) {
      statusColor = Colors.orange;
      statusText = 'Sắp hết hạn ($daysLeft ngày)';
    } else if (daysLeft < 0) {
      statusColor = Colors.red;
      statusText = 'Đã hết hạn';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withAlpha(77), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(u['full_name'] ?? 'No Name',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showEditUser(uid, u)),
              IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () =>
                      _confirmDeleteUser(uid, u['full_name'] ?? '')),
            ],
          ),
          Text('📞 ${u['phone'] ?? ''}'),
          Text('🔑 ${u['username'] ?? ''}'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🏭 Quyền truy cập: '),
              const SizedBox(width: 8),
              Chip(
                label: const Text('Kho 1'),
                backgroundColor: (u['access_kho1'] == true)
                    ? Colors.green[100]
                    : Colors.red[100],
              ),
              const SizedBox(width: 8),
              Chip(
                label: const Text('Kho 2'),
                backgroundColor: (u['access_kho2'] == true)
                    ? Colors.green[100]
                    : Colors.red[100],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('📅 Hết hạn: ${u['end_date'] ?? ''}'),
          Text('⏰ Thời gian còn lại: $daysLeft ngày'),
          Text('📊 Trạng thái: $statusText',
              style:
                  TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---------- Actions ----------
  void _showRentalSettings() {
    showDialog(
        context: context,
        builder: (_) =>
            RentalSettingsDialog(settings: _rentalSettings, onSaved: _loadAll));
  }

  void _showOwnerInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => OwnerInfoDialog(ownerInfo: _ownerInfo, onSaved: _loadAll),
    );
  }

  void _showAddUser() {
    showDialog(
        context: context, builder: (_) => AddUserDialog(onAdded: _loadAll));
  }

  void _showEditUser(String uid, Map<String, dynamic> data) {
    showDialog(
        context: context,
        builder: (_) =>
            EditUserDialog(userId: uid, userData: data, onUpdated: _loadAll));
  }

  void _confirmDeleteUser(String uid, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa người dùng'),
        content: Text('Bạn có chắc muốn xóa $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              try {
                await _db.child('owner/users/$uid').remove();
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa người dùng')));
                }
                _loadAll();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUẢN LÝ KHO'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') _showRentalSettings();
              if (v == 'owner_info') _showOwnerInfoDialog();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Cài đặt thuê bao')
                  ])),
              PopupMenuItem(
                  value: 'owner_info',
                  child: Row(children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Thông tin chủ kho')
                  ])),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOwnerInfoCard(),
                  const SizedBox(height: 16),
                  _buildStatsCard(stats),
                  const SizedBox(height: 16),
                  _buildRentalAlertsCard(stats),
                  if ((stats['expiringRentals'] ?? 0) > 0 ||
                      (stats['expiredRentals'] ?? 0) > 0)
                    const SizedBox(height: 16),
                  _buildWarehouseStatus(),
                  const SizedBox(height: 16),
                  _buildUsersSection(),
                ],
              ),
            ),
    );
  }
}

/// === OWNER INFO DIALOG ===
class OwnerInfoDialog extends StatefulWidget {
  final Map<String, dynamic> ownerInfo;
  final VoidCallback onSaved;
  const OwnerInfoDialog({
    super.key,
    required this.ownerInfo,
    required this.onSaved,
  });

  @override
  State<OwnerInfoDialog> createState() => _OwnerInfoDialogState();
}

class _OwnerInfoDialogState extends State<OwnerInfoDialog> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _address;
  late DatabaseReference _db;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
    _name = TextEditingController(text: widget.ownerInfo['name'] ?? '');
    _phone = TextEditingController(text: widget.ownerInfo['phone'] ?? '');
    _email = TextEditingController(text: widget.ownerInfo['email'] ?? '');
    _address = TextEditingController(text: widget.ownerInfo['address'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await _db.child('owner_info').set({
        'name': _name.text,
        'phone': _phone.text,
        'email': _email.text,
        'address': _address.text,
      });
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu thông tin chủ kho')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thông tin chủ kho'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}

/// === RENTAL SETTINGS DIALOG ===
class RentalSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> settings;
  final VoidCallback onSaved;
  const RentalSettingsDialog({
    super.key,
    required this.settings,
    required this.onSaved,
  });
  @override
  State<RentalSettingsDialog> createState() => _RentalSettingsDialogState();
}

class _RentalSettingsDialogState extends State<RentalSettingsDialog> {
  late TextEditingController _warning;
  bool _autoLock = true;
  late DatabaseReference _db;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
    _warning = TextEditingController(
      text: (widget.settings['warning_days'] ?? 7).toString(),
    );
    _autoLock = widget.settings['auto_lock_after_expiry'] ?? true;
  }

  @override
  void dispose() {
    _warning.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final days = int.tryParse(_warning.text) ?? 7;
      await _db.child('system/rental_settings').update({
        'warning_days': days,
        'auto_lock_after_expiry': _autoLock,
      });
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cài đặt thuê bao'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _warning,
            decoration: const InputDecoration(
              labelText: 'Số ngày cảnh báo trước',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _autoLock,
                onChanged: (b) => setState(() => _autoLock = b ?? true),
              ),
              const Expanded(child: Text('Tự động khóa tài khoản khi hết hạn')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}

/// === ADD USER DIALOG ===
class AddUserDialog extends StatefulWidget {
  final VoidCallback onAdded;
  const AddUserDialog({super.key, required this.onAdded});
  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  bool _accessKho1 = false;
  bool _accessKho2 = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  late DatabaseReference _db;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_form.currentState?.validate() != true) return;
    try {
      final lastSnap = await _db.child('system/last_user_id').get();
      int last = 0;
      if (lastSnap.exists) {
        final v = lastSnap.value;
        if (v is int)
          last = v;
        else if (v is String) last = int.tryParse(v) ?? 0;
      }
      final nid = last + 1;
      final uid = 'user${nid.toString().padLeft(3, '0')}';
      await _db.child('owner/users/$uid').set({
        'username': _username.text,
        'password': _password.text,
        'full_name': _fullName.text,
        'phone': _phone.text,
        'access_kho1': _accessKho1,
        'access_kho2': _accessKho2,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'status': 'active',
      });
      await _db.child('system/last_user_id').set(nid);
      if (mounted) {
        widget.onAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã thêm người dùng')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi thêm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người dùng mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Nhập tên đăng nhập' : null),
            TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu' : null),
            TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập họ tên' : null),
            TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Nhập số điện thoại' : null),
            const SizedBox(height: 12),
            Row(children: [
              Checkbox(
                  value: _accessKho1,
                  onChanged: (b) => setState(() => _accessKho1 = b ?? false)),
              const Text('Kho 1'),
              const SizedBox(width: 12),
              Checkbox(
                  value: _accessKho2,
                  onChanged: (b) => setState(() => _accessKho2 = b ?? false)),
              const Text('Kho 2'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(context),
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Ngày bắt đầu'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(context),
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Ngày kết thúc'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _save, child: const Text('Thêm'))
      ],
    );
  }
}

/// === EDIT USER DIALOG ===
class EditUserDialog extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final VoidCallback onUpdated;
  const EditUserDialog({
    super.key,
    required this.userId,
    required this.userData,
    required this.onUpdated,
  });
  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _username;
  late TextEditingController _password;
  late TextEditingController _fullName;
  late TextEditingController _phone;
  bool _accessKho1 = false;
  bool _accessKho2 = false;
  late DateTime _startDate;
  late DateTime _endDate;
  String _status = 'active';
  late DatabaseReference _db;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(app: Firebase.app('OwnerApp')).ref();
    _username = TextEditingController(text: widget.userData['username'] ?? '');
    _password = TextEditingController(text: widget.userData['password'] ?? '');
    _fullName = TextEditingController(text: widget.userData['full_name'] ?? '');
    _phone = TextEditingController(text: widget.userData['phone'] ?? '');
    _accessKho1 = widget.userData['access_kho1'] ?? false;
    _accessKho2 = widget.userData['access_kho2'] ?? false;

    try {
      _startDate =
          DateFormat('yyyy-MM-dd').parse(widget.userData['start_date'] ?? '');
    } catch (_) {
      _startDate = DateTime.now();
    }

    try {
      _endDate =
          DateFormat('yyyy-MM-dd').parse(widget.userData['end_date'] ?? '');
    } catch (_) {
      _endDate = DateTime.now().add(const Duration(days: 365));
    }

    _status = widget.userData['status'] ?? 'active';
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _update() async {
    if (_form.currentState?.validate() != true) {
      return;
    }

    try {
      await _db.child('owner/users/${widget.userId}').update({
        'username': _username.text,
        'password': _password.text,
        'full_name': _fullName.text,
        'phone': _phone.text,
        'access_kho1': _accessKho1,
        'access_kho2': _accessKho2,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'status': _status,
      });

      if (mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật người dùng')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa người dùng'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Nhập tên đăng nhập' : null,
              ),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu' : null,
              ),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) => (v ?? '').isEmpty ? 'Nhập họ tên' : null,
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Nhập số điện thoại' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _accessKho1,
                    onChanged: (b) => setState(() => _accessKho1 = b ?? false),
                  ),
                  const Text('Kho 1'),
                  const SizedBox(width: 12),
                  Checkbox(
                    value: _accessKho2,
                    onChanged: (b) => setState(() => _accessKho2 = b ?? false),
                  ),
                  const Text('Kho 2'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Ngày bắt đầu'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Ngày kết thúc'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(
                      value: 'active', child: Text('Đang hoạt động')),
                  DropdownMenuItem(value: 'inactive', child: Text('Đã khóa')),
                  DropdownMenuItem(value: 'expired', child: Text('Đã hết hạn')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
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
          onPressed: _update,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
