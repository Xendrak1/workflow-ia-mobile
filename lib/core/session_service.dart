import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kToken = 'wfia_token';
const _kRole = 'wfia_role';
const _kEmail = 'wfia_email';
const _kFullName = 'wfia_full_name';
const _kDepartment = 'wfia_department';
const _kUserId = 'wfia_user_id';
const _kPlan = 'wfia_plan';

class SessionService extends ChangeNotifier {
  String? _token;
  String? _role;
  String? _email;
  String? _fullName;
  String? _department;
  String? _userId;
  String? _plan;

  String? get token => _token;
  String? get role => _role;
  String? get email => _email;
  String? get fullName => _fullName;
  String? get department => _department;
  String? get userId => _userId;
  String? get plan => _plan;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'administrador';
  bool get isFuncionario => _role == 'funcionario';
  bool get isSupervisor => _role == 'supervisor';
  bool get isCliente => _role == 'cliente';

  String get initials {
    if (_fullName == null || _fullName!.isEmpty) return '?';
    final parts = _fullName!.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
    _role = prefs.getString(_kRole);
    _email = prefs.getString(_kEmail);
    _fullName = prefs.getString(_kFullName);
    _department = prefs.getString(_kDepartment);
    _userId = prefs.getString(_kUserId);
    _plan = prefs.getString(_kPlan);
    notifyListeners();
  }

  Future<void> save({
    required String token,
    required String role,
    required String email,
    required String fullName,
    String? department,
    String? userId,
    String? plan,
  }) async {
    _token = token;
    _role = role;
    _email = email;
    _fullName = fullName;
    _department = department;
    _userId = userId;
    _plan = plan ?? 'starter';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kFullName, fullName);
    if (department != null) await prefs.setString(_kDepartment, department);
    if (userId != null) await prefs.setString(_kUserId, userId);
    await prefs.setString(_kPlan, _plan!);
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _role = null;
    _email = null;
    _fullName = null;
    _department = null;
    _userId = null;
    _plan = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
