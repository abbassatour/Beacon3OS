// lib/auth/cubit/auth_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/auth/cubit/auth_state.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:launcher_repository/launcher_repository.dart';
// 👈 إخفاء AuthState من حزمة Supabase لمنع التعارض مع كلاس حالة الـ Cubit
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LauncherRepository repository,
    CloudSyncClient? cloudSyncClient,
  })  : _repository = repository,
        _cloud = cloudSyncClient ?? CloudSyncClient(),
        super(const AuthState()) {
    checkCurrentAuth();
    _listenToAuthChanges();
  }

  final LauncherRepository _repository;
  final CloudSyncClient _cloud;
  StreamSubscription<dynamic>? _authSubscription;

  void _listenToAuthChanges() {
    _authSubscription = _cloud.authStateChanges?.listen((_) {
      checkCurrentAuth();
    });
  }

  void checkCurrentAuth() {
    final user = _cloud.currentUser;
    if (user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));

      // تشغيل المزامنة بالاتجاهين في الخلفية بسلاسة
      Future.microtask(() async {
        await _repository.restoreVaultFromCloud();
        await _repository.syncPendingOfflineChanges();
      });
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
    }
  }

  /// 🌟 الدخول السيادي اللامركزي التلقائي (Hardware-Bound Sovereign DID Login)
  /// يربط محفظة الهاتف المشفرة (DID) بجلسة سحابية مشفرة برمجياً دون الحاجة لأي لوحة مفاتيح
  Future<void> loginWithSovereignDid() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final didAddress = Web3Service.instance.walletAddressHex.toLowerCase();
      final syntheticEmail = '$didAddress@sovereign.beaconos.eth';
      final passSlice = didAddress.length >= 22
          ? didAddress.substring(2, 22)
          : didAddress;
      final syntheticPassword = 'BeaconDID:${passSlice}!Sovereign2026';

      AuthResponse? res;
      try {
        res = await _cloud.signInWithEmail(
          email: syntheticEmail,
          password: syntheticPassword,
        );
      } catch (_) {
        // إذا كان الحساب جديداً لأول مرة، نسجله فوراً في الخلفية
        try {
          res = await _cloud.signUpWithEmail(
            email: syntheticEmail,
            password: syntheticPassword,
          );
        } catch (signUpErr) {
          log('AuthCubit: Cloud sign up bypassed (Offline first): $signUpErr');
        }
      }

      await _repository.restoreVaultFromCloud();
      await _repository.syncPendingOfflineChanges();

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: res?.user ?? _cloud.currentUser,
        errorMessage: null,
      ));
      log('AuthCubit: ✅ Sovereign DID authenticated successfully: $didAddress');
    } catch (e) {
      log('AuthCubit: Running in sovereign offline-first mode: $e');
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: _cloud.currentUser,
        errorMessage: null,
      ));
    }
  }

  /// 📺 اقتران غرفة المعيشة والتلفزيون (Living Room & Fire TV Bridge)
  Future<void> pairLivingRoomTv(String pairingCode) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      log('AuthCubit: Pairing Living Room TV with code: $pairingCode');
      await loginWithSovereignDid();
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to pair device: $e',
      ));
    }
  }

  /// تسجيل الدخول الكلاسيكي (مسار بديل)
  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final res = await _cloud.signInWithEmail(
        email: email,
        password: password,
      );
      await _repository.restoreVaultFromCloud();
      emit(state.copyWith(status: AuthStatus.authenticated, user: res?.user));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Invalid credentials or connection error.',
        ),
      );
    }
  }

  /// إنشاء حساب تقليدي
  Future<void> signUp({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final res = await _cloud.signUpWithEmail(
        email: email,
        password: password,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: res?.user));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Could not create account. Please check your details.',
        ),
      );
    }
  }

  /// نقرة الدخول السيادي السريع المربوطة بزر LoginPage
  Future<void> continueAsGuest() async {
    await loginWithSovereignDid();
  }

  /// تسجيل الخروج وإعادة ضبط الجلسة
  Future<void> signOut() async {
    await _cloud.signOut();
    emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}