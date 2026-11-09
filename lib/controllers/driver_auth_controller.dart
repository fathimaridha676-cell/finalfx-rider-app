import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver_profile_model.dart';
import '../repositories/driver_auth_repository.dart';

/// Holds the currently logged-in driver's profile
final currentDriverProfileProvider =
    StateNotifierProvider<CurrentDriverNotifier, AsyncValue<DriverProfileModel?>>((ref) {
  return CurrentDriverNotifier(ref);
});

class CurrentDriverNotifier extends StateNotifier<AsyncValue<DriverProfileModel?>> {
  final Ref _ref;

  CurrentDriverNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _init();
  }

  void _init() {
    // Automatically listen to auth state changes
    _ref.listen(authStateProvider, (previous, next) async {
      final user = next.value;
      if (user == null) {
        state = const AsyncValue.data(null);
      } else if (user.email != null) {
        state = const AsyncValue.loading();
        try {
          final profile = await _ref
              .read(driverAuthRepositoryProvider)
              .fetchDriverProfileByEmail(user.email!);
          state = AsyncValue.data(profile);
        } catch (e, st) {
          state = AsyncValue.error(e, st);
        }
      }
    });
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final profile = await _ref
          .read(driverAuthRepositoryProvider)
          .login(email: email, password: password);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    try {
      final profile = await _ref
          .read(driverAuthRepositoryProvider)
          .loginWithGoogle();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _ref.read(driverAuthRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
  }
}

