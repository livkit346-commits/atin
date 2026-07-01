import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:uuid/uuid.dart';
import 'supabase_config.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const AtinApp());
}

final supabase = Supabase.instance.client;

class AtinApp extends StatelessWidget {
  const AtinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Atin Attendance',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: Colors.blueAccent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
              primary: Colors.blue,
              secondary: Colors.blueAccent,
              background: const Color(0xFFF6F8FA),
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F8FA),
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 2,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: Colors.blueAccent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              primary: Colors.blueAccent,
              secondary: Colors.blue,
              background: const Color(0xFF121212),
              surface: const Color(0xFF1E1E1E),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E1E1E),
              elevation: 4,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const OrganizationGate();
        }
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // Custom Profile Fields
  String _gender = 'Male';
  final _departmentController = TextEditingController();
  final _levelController = TextEditingController();
  final _schoolController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': _nameController.text.trim(),
            'gender': _gender,
            'department': _departmentController.text.trim(),
            'level': _levelController.text.trim(),
            'school': _schoolController.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please log in.')),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignUp ? 'Create Atin Account' : 'Welcome to Atin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.primary
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                        ],
                        onChanged: (val) => setState(() => _gender = val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _schoolController,
                        decoration: const InputDecoration(labelText: 'School / Institution', prefixIcon: Icon(Icons.school)),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter school' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business)),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter department' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _levelController,
                        decoration: const InputDecoration(labelText: 'Level / Year', prefixIcon: Icon(Icons.grade)),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter level' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Gmail / Email', prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Please enter valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => v == null || v.length < 6 ? 'Password must be 6+ chars' : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_isSignUp ? 'Sign Up' : 'Log In', style: const TextStyle(fontSize: 16)),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp ? 'Already have an account? Log In' : 'Need an account? Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrganizationGate extends StatefulWidget {
  const OrganizationGate({super.key});

  @override
  State<OrganizationGate> createState() => _OrganizationGateState();
}

class _OrganizationGateState extends State<OrganizationGate> {
  bool _loading = true;
  Map<String, dynamic>? _organizationMembership;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await supabase
            .from('organization_members')
            .select('*, organizations(*)')
            .eq('user_id', user.id)
            .maybeSingle();

        setState(() {
          _organizationMembership = res;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_organizationMembership == null) {
      return OnboardingScreen(onCompleted: _checkMembership);
    }

    final org = _organizationMembership!['organizations'] as Map<String, dynamic>;
    final role = _organizationMembership!['role'] as String;

    return DashboardWrapper(organization: org, userRole: role);
  }
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _createController = TextEditingController();
  List<dynamic> _availableOrgs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    try {
      final res = await supabase.from('organizations').select();
      setState(() {
        _availableOrgs = res as List<dynamic>;
      });
    } catch (e) {
      // Handle silently
    }
  }

  Future<void> _createOrg() async {
    if (_createController.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      await supabase.from('organizations').insert({
        'name': _createController.text.trim(),
        'type': 'SIWES Attendance Group',
        'created_by': user!.id,
      });
      widget.onCompleted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _joinOrg(String orgId) async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      await supabase.from('organization_members').insert({
        'organization_id': orgId,
        'user_id': user!.id,
        'role': 'member',
      });
      widget.onCompleted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Organization'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => supabase.auth.signOut()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Create a SIWES Attendance Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _createController,
                            decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g., SIWES Section B'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _createOrg,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Create & Become Admin'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Or Join an Existing Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_availableOrgs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: const Text('No groups available to join yet.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    )
                  else
                    ..._availableOrgs.map((org) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(org['name']),
                          subtitle: Text(org['type']),
                          trailing: ElevatedButton(
                            onPressed: () => _joinOrg(org['id']),
                            child: const Text('Join'),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }
}

class DashboardWrapper extends StatefulWidget {
  final Map<String, dynamic> organization;
  final String userRole;
  const DashboardWrapper({super.key, required this.organization, required this.userRole});

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileName();
  }

  Future<void> _fetchProfileName() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase.from('profiles').select().eq('id', user.id).single();
        setState(() {
          _name = data['name'];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.userRole == 'admin') {
      return AdminDashboard(adminName: _name ?? 'Admin', organization: widget.organization);
    }
    return StudentDashboard(studentName: _name ?? 'Student', organization: widget.organization);
  }
}

class StudentDashboard extends StatefulWidget {
  final String studentName;
  final Map<String, dynamic> organization;
  const StudentDashboard({super.key, required this.studentName, required this.organization});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      StudentCheckInTab(studentName: widget.studentName, organization: widget.organization),
      const StudentHistoryTab(),
      StudentProfileTab(studentName: widget.studentName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.organization['name'] ?? 'Student'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Check In'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class StudentCheckInTab extends StatefulWidget {
  final String studentName;
  final Map<String, dynamic> organization;
  const StudentCheckInTab({super.key, required this.studentName, required this.organization});

  @override
  State<StudentCheckInTab> createState() => _StudentCheckInTabState();
}

class _StudentCheckInTabState extends State<StudentCheckInTab> {
  Map<String, dynamic>? _activeSession;
  bool _inGpsRange = false;
  bool _inBleRange = false;
  double _distance = 0.0;
  bool _scanning = false;
  bool _checkedIn = false;
  Map<String, dynamic>? _attendanceRecord;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _listenToActiveSession();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _listenToActiveSession() {
    supabase
        .from('attendance_sessions')
        .stream(primaryKey: ['id'])
        .eq('organization_id', widget.organization['id'])
        .listen((data) {
          Map<String, dynamic>? active;
          final now = DateTime.now();

          for (final item in data) {
            if (item['is_active'] == true) {
              if (item['is_recurring'] == true) {
                if (now.weekday >= 1 && now.weekday <= 5) {
                  final currentMinutes = now.hour * 60 + now.minute;
                  final startParts = item['daily_start_time'].split(':');
                  final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                  final endParts = item['daily_end_time'].split(':');
                  final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

                  if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
                    active = item;
                    break;
                  }
                }
              } else {
                final start = DateTime.parse(item['start_time']);
                final expires = DateTime.parse(item['expires_at']);
                if (now.isAfter(start) && now.isBefore(expires)) {
                  active = item;
                  break;
                }
              }
            }
          }

          if (active != null) {
            setState(() {
              _activeSession = active;
            });
            _runRangeChecks();
            _checkExistingAttendance();
          } else {
            setState(() {
              _activeSession = null;
              _inGpsRange = false;
              _inBleRange = false;
            });
            _stopHeartbeat();
          }
        });
  }

  Future<void> _checkExistingAttendance() async {
    if (_activeSession == null) return;
    final user = supabase.auth.currentUser;
    final res = await supabase
        .from('attendances')
        .select()
        .eq('student_id', user!.id)
        .eq('session_id', _activeSession!['id'])
        .eq('date', DateTime.now().toIso8601String().substring(0, 10))
        .maybeSingle();

    if (res != null) {
      setState(() {
        _checkedIn = true;
        _attendanceRecord = res;
      });
      _startHeartbeat();
    } else {
      setState(() {
        _checkedIn = false;
        _attendanceRecord = null;
      });
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!_checkedIn || _attendanceRecord == null || _activeSession == null) {
        timer.cancel();
        return;
      }
      
      // Perform hardware range checks dynamically
      await _runRangeChecks();
      
      final bool withinRange = _inGpsRange && _inBleRange;
      if (withinRange) {
        // Still in location range, update heartbeat seen timestamp
        try {
          await supabase.from('attendances').update({
            'last_seen': DateTime.now().toIso8601String(),
          }).eq('id', _attendanceRecord!['id']);
        } catch (e) {
          // Ignored
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _runRangeChecks() async {
    if (_activeSession == null) return;

    final authType = _activeSession!['auth_type'];

    if (authType == 'gps' || authType == 'both') {
      await _checkGps();
    } else {
      setState(() => _inGpsRange = true);
    }

    if (authType == 'ble' || authType == 'both') {
      await _scanBle();
    } else {
      setState(() => _inBleRange = true);
    }
  }

  Future<void> _checkGps() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final position = await Geolocator.getCurrentPosition();
    final double targetLat = _activeSession!['latitude'];
    final double targetLng = _activeSession!['longitude'];
    final int radius = _activeSession!['radius_meters'];

    final distanceMeters = _coordinateDistance(position.latitude, position.longitude, targetLat, targetLng);

    setState(() {
      _distance = distanceMeters;
      _inGpsRange = distanceMeters <= radius;
    });
  }

  double _coordinateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  Future<void> _scanBle() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    try {
      final bleUuid = _activeSession!['ble_uuid']?.toString().toLowerCase();
      if (bleUuid == null) return;

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          final uuidMatched = r.advertisementData.serviceUuids.any((uuid) => uuid.toString().toLowerCase() == bleUuid);
          if (uuidMatched) {
            setState(() {
              _inBleRange = true;
            });
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      // Ignored
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _checkIn() async {
    if (_activeSession == null) return;
    final user = supabase.auth.currentUser;

    try {
      final res = await supabase.from('attendances').insert({
        'student_id': user!.id,
        'session_id': _activeSession!['id'],
        'check_in': DateTime.now().toIso8601String(),
        'last_seen': DateTime.now().toIso8601String(),
      }).select().single();

      setState(() {
        _checkedIn = true;
        _attendanceRecord = res;
      });
      _startHeartbeat();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully Checked In!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _checkOut() async {
    if (_attendanceRecord == null) return;
    try {
      await supabase.from('attendances').update({
        'check_out': DateTime.now().toIso8601String(),
      }).eq('id', _attendanceRecord!['id']);

      setState(() {
        _checkedIn = false;
        _activeSession = null;
      });
      _stopHeartbeat();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully Checked Out!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool withinTotalRange = _inGpsRange && _inBleRange;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_activeSession == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.offline_pin_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No Active Attendance Session', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Wait for the admin to launch check-in.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeSession!['title'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Text('Verification Method: ${_activeSession!['auth_type'].toString().toUpperCase()}', style: const TextStyle(color: Colors.grey)),
                    if (_activeSession!['is_recurring'] == true) ...[
                      const SizedBox(height: 4),
                      Text('Recurring Schedule: Mon-Fri (${_activeSession!['daily_start_time']} to ${_activeSession!['daily_end_time']})', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                    ],
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GPS Range Check:'),
                        Icon(
                          _inGpsRange ? Icons.check_circle : Icons.cancel,
                          color: _inGpsRange ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ],
                    ),
                    if (_activeSession!['auth_type'] == 'gps' || _activeSession!['auth_type'] == 'both')
                      Text('Distance: ${_distance.toStringAsFixed(1)}m / ${_activeSession!['radius_meters']}m radius', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('BLE Signal Check:'),
                        Icon(
                          _inBleRange ? Icons.check_circle : Icons.cancel,
                          color: _inBleRange ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_scanning) const Center(child: LinearProgressIndicator(color: Colors.blueAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_checkedIn)
              ElevatedButton.icon(
                onPressed: _checkOut,
                icon: const Icon(Icons.logout),
                label: const Text('Check Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: withinTotalRange ? _checkIn : null,
                icon: const Icon(Icons.login),
                label: const Text('Check In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class StudentHistoryTab extends StatelessWidget {
  const StudentHistoryTab({super.key});

  Future<List<dynamic>> _fetchHistory() async {
    final user = supabase.auth.currentUser;
    final response = await supabase
        .from('attendances')
        .select('*, attendance_sessions(*)')
        .eq('student_id', user!.id)
        .order('check_in', ascending: false);
    return response as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No check-in history found.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final log = data[index];
            final session = log['attendance_sessions'] as Map<String, dynamic>;
            final checkInTime = DateTime.parse(log['check_in']).toLocal();
            final checkOutTimeRaw = log['check_out'];
            final lastSeenTime = DateTime.parse(log['last_seen']).toLocal();
            
            DateTime? checkOutTime;
            bool isAutoCheckedOut = false;
            bool isLastSeenOut = false;
            
            if (checkOutTimeRaw != null) {
              checkOutTime = DateTime.parse(checkOutTimeRaw).toLocal();
            } else {
              final now = DateTime.now();
              DateTime sessionEndTimeToday;
              
              if (session['is_recurring'] == true) {
                final endParts = session['daily_end_time'].split(':');
                final endHour = int.parse(endParts[0]);
                final endMin = int.parse(endParts[1]);
                sessionEndTimeToday = DateTime(checkInTime.year, checkInTime.month, checkInTime.day, endHour, endMin);
              } else {
                sessionEndTimeToday = DateTime.parse(session['expires_at']).toLocal();
              }
              
              if (now.isAfter(sessionEndTimeToday)) {
                // If they never checked out and left the location before it ended:
                // lastSeen represents the exact latest moment they were in range.
                // We check if lastSeen is before the session end time.
                if (lastSeenTime.isBefore(sessionEndTimeToday)) {
                  checkOutTime = lastSeenTime;
                  isLastSeenOut = true;
                } else {
                  checkOutTime = sessionEndTimeToday;
                  isAutoCheckedOut = true;
                }
              }
            }

            String statusLabel = 'Active';
            Color statusColor = Colors.orangeAccent;
            if (checkOutTime != null) {
              statusColor = isLastSeenOut ? Colors.blueGrey : (isAutoCheckedOut ? Colors.orange : Colors.greenAccent);
              statusLabel = isLastSeenOut ? 'Left Location' : (isAutoCheckedOut ? 'Auto Closed' : 'Completed');
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(session['title'] ?? 'Session', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Date: ${log['date']}'),
                    Text('Check In: ${checkInTime.hour}:${checkInTime.minute.toString().padLeft(2, '0')}'),
                    if (checkOutTime != null)
                      Text(
                        isLastSeenOut
                            ? 'Last Seen (Auto Out): ${checkOutTime.hour}:${checkOutTime.minute.toString().padLeft(2, '0')}'
                            : (isAutoCheckedOut
                                ? 'Auto Checked Out: ${checkOutTime.hour}:${checkOutTime.minute.toString().padLeft(2, '0')}'
                                : 'Check Out: ${checkOutTime.hour}:${checkOutTime.minute.toString().padLeft(2, '0')}'), 
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)
                      )
                    else
                      const Text('Check Out: Pending', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class StudentProfileTab extends StatelessWidget {
  final String studentName;
  const StudentProfileTab({super.key, required this.studentName});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return FutureBuilder<Map<String, dynamic>>(
      future: supabase.from('profiles').select().eq('id', user!.id).single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(studentName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(profile['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _profileInfoRow('Gender', profile['gender'] ?? 'N/A'),
                      _profileInfoRow('School', profile['school'] ?? 'N/A'),
                      _profileInfoRow('Department', profile['department'] ?? 'N/A'),
                      _profileInfoRow('Level', profile['level'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 40),
              FutureBuilder<List<dynamic>>(
                future: supabase.from('attendances').select().eq('student_id', user.id),
                builder: (context, snap) {
                  final count = snap.hasData ? snap.data!.length : 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 4),
                          const Text('Total Classes', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Active', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          const SizedBox(height: 4),
                          const Text('Status', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final String adminName;
  final Map<String, dynamic> organization;
  const AdminDashboard({super.key, required this.adminName, required this.organization});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      AdminConsoleTab(adminName: widget.adminName, organization: widget.organization),
      const AdminReportsTab(),
      AdminMembersTab(organization: widget.organization),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.organization['name']} Admin'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Session'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
        ],
      ),
    );
  }
}

class AdminConsoleTab extends StatefulWidget {
  final String adminName;
  final Map<String, dynamic> organization;
  const AdminConsoleTab({super.key, required this.adminName, required this.organization});

  @override
  State<AdminConsoleTab> createState() => _AdminConsoleTabState();
}

class _AdminConsoleTabState extends State<AdminConsoleTab> {
  final _titleController = TextEditingController();
  String _authType = 'gps';
  
  // Scheduling States
  bool _isRecurring = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isPublishing = false;
  Map<String, dynamic>? _activeSession;
  List<dynamic> _attendees = [];
  Timer? _attendanceRefreshTimer;

  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _attendanceRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveSession() async {
    final user = supabase.auth.currentUser;
    final res = await supabase
        .from('attendance_sessions')
        .select()
        .eq('organization_id', widget.organization['id'])
        .eq('admin_id', user!.id)
        .eq('is_active', true)
        .maybeSingle();

    if (res != null) {
      if (res['is_recurring'] == true) {
        setState(() {
          _activeSession = res;
        });
        _startBroadcastingIfNeeded();
        _startAttendeePolling();
      } else {
        final expires = DateTime.parse(res['expires_at']);
        if (expires.isAfter(DateTime.now())) {
          setState(() {
            _activeSession = res;
          });
          _startBroadcastingIfNeeded();
          _startAttendeePolling();
        } else {
          await supabase.from('attendance_sessions').update({'is_active': false}).eq('id', res['id']);
        }
      }
    }
  }

  Future<void> _startAttendeePolling() async {
    _attendanceRefreshTimer?.cancel();
    _fetchAttendees();
    _attendanceRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAttendees());
  }

  Future<void> _fetchAttendees() async {
    if (_activeSession == null) return;
    try {
      final res = await supabase
          .from('attendances')
          .select('check_in, check_out, last_seen, profiles(*)')
          .eq('session_id', _activeSession!['id']);
      setState(() {
        _attendees = res;
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _startBroadcastingIfNeeded() async {
    if (_activeSession == null || _activeSession!['ble_uuid'] == null) return;
    
    final AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: _activeSession!['ble_uuid'],
      localName: 'Atin-Admin',
    );
    await blePeripheral.start(advertiseData: advertiseData);
  }

  Future<void> _stopBroadcasting() async {
    await blePeripheral.stop();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _startSession() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isPublishing = true);

    try {
      final user = supabase.auth.currentUser;
      double? lat;
      double? lng;
      String? bleUuid;

      if (_authType == 'gps' || _authType == 'both') {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled on this device.');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied.');
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied. Please enable them in settings.');
        }

        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      }

      if (_authType == 'ble' || _authType == 'both') {
        bleUuid = const Uuid().v4();
      }

      DateTime startTime;
      DateTime expiresTime;
      String? dailyStart;
      String? dailyEnd;

      final now = DateTime.now();

      if (_isRecurring) {
        dailyStart = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
        dailyEnd = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';
        startTime = now;
        expiresTime = now.add(const Duration(days: 365));
      } else {
        startTime = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
        expiresTime = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);
        if (expiresTime.isBefore(startTime)) {
          expiresTime = expiresTime.add(const Duration(days: 1));
        }
      }

      final res = await supabase.from('attendance_sessions').insert({
        'organization_id': widget.organization['id'],
        'admin_id': user!.id,
        'title': _titleController.text.trim(),
        'auth_type': _authType,
        'latitude': lat,
        'longitude': lng,
        'ble_uuid': bleUuid,
        'is_recurring': _isRecurring,
        'daily_start_time': dailyStart,
        'daily_end_time': dailyEnd,
        'start_time': startTime.toIso8601String(),
        'expires_at': expiresTime.toIso8601String(),
        'is_active': true,
      }).select().single();

      setState(() {
        _activeSession = res;
      });

      await _startBroadcastingIfNeeded();
      _startAttendeePolling();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  Future<void> _endSession() async {
    if (_activeSession == null) return;
    try {
      await supabase.from('attendance_sessions').update({
        'is_active': false,
      }).eq('id', _activeSession!['id']);

      await _stopBroadcasting();
      _attendanceRefreshTimer?.cancel();

      setState(() {
        _activeSession = null;
        _attendees = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_activeSession == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Session Title (e.g., Mathematics 101)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _authType,
                      decoration: const InputDecoration(labelText: 'Verification Strategy'),
                      items: const [
                        DropdownMenuItem(value: 'gps', child: Text('Google Location (GPS) Only')),
                        DropdownMenuItem(value: 'ble', child: Text('BLE Beacon Only')),
                        DropdownMenuItem(value: 'both', child: Text('Both GPS & BLE')),
                      ],
                      onChanged: (val) => setState(() => _authType = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Repeat Every Working Day (Mon-Fri)', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isRecurring,
                          onChanged: (val) => setState(() => _isRecurring = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(true),
                            icon: const Icon(Icons.access_time),
                            label: Text('Starts: ${_startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(false),
                            icon: const Icon(Icons.av_timer),
                            label: Text('Ends: ${_endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _isPublishing
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _startSession,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16)
                            ),
                            child: const Text('Publish Session'),
                          ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Active: ${_activeSession!['title']}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _endSession,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          child: const Text('End Session'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Method: ${_activeSession!['auth_type'].toString().toUpperCase()}', style: const TextStyle(color: Colors.grey)),
                    if (_activeSession!['is_recurring'] == true) ...[
                      const SizedBox(height: 4),
                      Text('Recurring: Mon-Fri (${_activeSession!['daily_start_time']} to ${_activeSession!['daily_end_time']})', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('Active Window: ${DateTime.parse(_activeSession!['start_time']).toLocal().hour}:${DateTime.parse(_activeSession!['start_time']).toLocal().minute.toString().padLeft(2, '0')} to ${DateTime.parse(_activeSession!['expires_at']).toLocal().hour}:${DateTime.parse(_activeSession!['expires_at']).toLocal().minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.blueGrey)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Attendees Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _attendees.length,
                itemBuilder: (context, index) {
                  final a = _attendees[index];
                  final profile = a['profiles'] as Map<String, dynamic>;
                  final checkIn = DateTime.parse(a['check_in']).toLocal();
                  final checkOutRaw = a['check_out'];
                  final lastSeenTime = DateTime.parse(a['last_seen']).toLocal();
                  
                  DateTime? checkOut;
                  bool isAutoChecked = false;
                  bool isLastSeenOut = false;
                  
                  if (checkOutRaw != null) {
                    checkOut = DateTime.parse(checkOutRaw).toLocal();
                  } else {
                    final now = DateTime.now();
                    DateTime limit;
                    
                    if (_activeSession!['is_recurring'] == true) {
                      final endParts = _activeSession!['daily_end_time'].split(':');
                      final endH = int.parse(endParts[0]);
                      final endM = int.parse(endParts[1]);
                      limit = DateTime(checkIn.year, checkIn.month, checkIn.day, endH, endM);
                    } else {
                      limit = DateTime.parse(_activeSession!['expires_at']).toLocal();
                    }
                    
                    if (now.isAfter(limit)) {
                      if (lastSeenTime.isBefore(limit)) {
                        checkOut = lastSeenTime;
                        isLastSeenOut = true;
                      } else {
                        checkOut = limit;
                        isAutoChecked = true;
                      }
                    }
                  }

                  String subStatus = 'Active';
                  Color subColor = Colors.greenAccent;
                  if (checkOut != null) {
                    subColor = isLastSeenOut ? Colors.orangeAccent : (isAutoChecked ? Colors.orange : Colors.grey);
                    subStatus = isLastSeenOut ? 'Left Location' : (isAutoChecked ? 'Auto Closed' : 'Completed');
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(profile['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                subStatus,
                                style: TextStyle(
                                  color: subColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Email: ${profile['email'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Gender: ${profile['gender'] ?? ''} • School: ${profile['school'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Dept: ${profile['department'] ?? ''} • Level: ${profile['level'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('In: ${checkIn.hour}:${checkIn.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                              if (checkOut != null)
                               Text(
                                 isLastSeenOut
                                     ? 'Last Seen: ${checkOut.hour}:${checkOut.minute.toString().padLeft(2, '0')}'
                                     : (isAutoChecked 
                                         ? 'Auto Out: ${checkOut.hour}:${checkOut.minute.toString().padLeft(2, '0')}'
                                         : 'Out: ${checkOut.hour}:${checkOut.minute.toString().padLeft(2, '0')}'), 
                                 style: TextStyle(fontSize: 12, color: subColor)
                               )
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  Future<List<dynamic>> _fetchSessions() async {
    final user = supabase.auth.currentUser;
    final response = await supabase
        .from('attendance_sessions')
        .select('*, attendances(count)')
        .eq('admin_id', user!.id)
        .order('created_at', ascending: false);
    return response as List<dynamic>;
  }

  void _showSessionDetails(BuildContext context, Map<String, dynamic> session) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<List<dynamic>>(
              future: supabase
                  .from('attendances')
                  .select('check_in, check_out, last_seen, profiles(*)')
                  .eq('session_id', session['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? [];
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['title'] ?? 'Session Details', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Method: ${session['auth_type'].toString().toUpperCase()}', style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 24),
                      Text('Students Present (${list.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: list.isEmpty
                            ? const Center(child: Text('No students checked in.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: list.length,
                                itemBuilder: (context, idx) {
                                  final attendee = list[idx];
                                  final profile = attendee['profiles'] as Map<String, dynamic>;
                                  final inTime = DateTime.parse(attendee['check_in']).toLocal();
                                  final outTimeRaw = attendee['check_out'];
                                  final lastSeenTime = DateTime.parse(attendee['last_seen']).toLocal();
                                  
                                  DateTime? outTime;
                                  bool autoOut = false;
                                  bool lastSeenOut = false;
                                  if (outTimeRaw != null) {
                                    outTime = DateTime.parse(outTimeRaw).toLocal();
                                  } else {
                                    final now = DateTime.now();
                                    DateTime limit;
                                    if (session['is_recurring'] == true) {
                                      final endParts = session['daily_end_time'].split(':');
                                      final endH = int.parse(endParts[0]);
                                      final endM = int.parse(endParts[1]);
                                      limit = DateTime(inTime.year, inTime.month, inTime.day, endH, endM);
                                    } else {
                                      limit = DateTime.parse(session['expires_at']).toLocal();
                                    }
                                    
                                    if (now.isAfter(limit)) {
                                      if (lastSeenTime.isBefore(limit)) {
                                        outTime = lastSeenTime;
                                        lastSeenOut = true;
                                      } else {
                                        outTime = limit;
                                        autoOut = true;
                                      }
                                    }
                                  }

                                  String infoSuffix = '';
                                  Color txtColor = Theme.of(context).colorScheme.primary;
                                  if (outTime != null) {
                                    if (lastSeenOut) {
                                      txtColor = Colors.orangeAccent;
                                      infoSuffix = ' | Left Location: ${outTime.hour}:${outTime.minute.toString().padLeft(2, '0')}';
                                    } else if (autoOut) {
                                      txtColor = Colors.orange;
                                      infoSuffix = ' | Auto Out: ${outTime.hour}:${outTime.minute.toString().padLeft(2, '0')}';
                                    } else {
                                      infoSuffix = ' | Out: ${outTime.hour}:${outTime.minute.toString().padLeft(2, '0')}';
                                    }
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(profile['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Email: ${profile['email'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('Gender: ${profile['gender'] ?? ''} • Dept: ${profile['department'] ?? ''} • Level: ${profile['level'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('In: ${inTime.hour}:${inTime.minute.toString().padLeft(2, '0')}$infoSuffix', style: TextStyle(color: txtColor, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No past sessions to report.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final sessions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final s = sessions[index];
            final created = DateTime.parse(s['created_at']).toLocal();
            final count = s['attendances'] != null && s['attendances'].isNotEmpty
                ? s['attendances'][0]['count']
                : 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(s['title'] ?? 'Session', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  s['is_recurring'] == true
                      ? 'Recurring: Mon-Fri (${s['daily_start_time']} - ${s['daily_end_time']})'
                      : 'Date: ${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} (${DateTime.parse(s['start_time']).toLocal().hour}:${DateTime.parse(s['start_time']).toLocal().minute.toString().padLeft(2, '0')} - ${DateTime.parse(s['expires_at']).toLocal().hour}:${DateTime.parse(s['expires_at']).toLocal().minute.toString().padLeft(2, '0')})'
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count Attended', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () => _showSessionDetails(context, s),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminMembersTab extends StatefulWidget {
  final Map<String, dynamic> organization;
  const AdminMembersTab({super.key, required this.organization});

  @override
  State<AdminMembersTab> createState() => _AdminMembersTabState();
}

class _AdminMembersTabState extends State<AdminMembersTab> {
  Future<List<dynamic>> _fetchMembers() async {
    final response = await supabase
        .from('organization_members')
        .select('*, profiles(*)')
        .eq('organization_id', widget.organization['id']);
    return response as List<dynamic>;
  }

  Future<void> _toggleAdmin(String memberId, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    try {
      await supabase
          .from('organization_members')
          .update({'role': newRole})
          .eq('id', memberId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated user role to $newRole!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchMembers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final m = list[index];
            final profile = m['profiles'] as Map<String, dynamic>;
            final role = m['role'] as String;

            return Card(
              child: ListTile(
                title: Text(profile['name'] ?? 'Unknown'),
                subtitle: Text('${profile['email'] ?? ''}\nGender: ${profile['gender'] ?? 'N/A'} • Dept: ${profile['department'] ?? 'N/A'}'),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => _toggleAdmin(m['id'], role),
                  child: Text(
                    role == 'admin' ? 'Revoke Admin' : 'Make Admin',
                    style: TextStyle(color: role == 'admin' ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
