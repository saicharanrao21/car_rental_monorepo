import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSessionState {
  final bool isAuthenticated;
  final String displayName;

  const AdminSessionState({
    required this.isAuthenticated,
    required this.displayName,
  });

  factory AdminSessionState.unauthenticated() =>
      const AdminSessionState(isAuthenticated: false, displayName: '');

  factory AdminSessionState.authenticated(String name) =>
      AdminSessionState(isAuthenticated: true, displayName: name);
}

class AdminSessionNotifier extends Notifier<AdminSessionState> {
  @override
  AdminSessionState build() {
    return AdminSessionState.unauthenticated();
  }

  void login(String name) {
    state = AdminSessionState.authenticated(name);
  }

  void logout() {
    state = AdminSessionState.unauthenticated();
  }
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSessionState>(AdminSessionNotifier.new);
