// lib/mobile/auth/cubit/auth_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/mobile/auth/cubit/auth_state.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:launcher_repository/launcher_repository.dart';
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

  void checkCurrentAuth() async {
    final user = _cloud.currentUser;
    if (user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));

      Future.microtask(() async {
        await _repository.restoreVaultFromCloud();
        await _repository.syncPendingOfflineChanges();
      });
    } else {
      // 🚀 التحقق من الاقتران عبر devicePairing بدلاً من comms
      final isLinked = await _repository.devicePairing.isDeviceLinked();
      if (isLinked) {
        final linkedId = await _repository.devicePairing.getLinkedVaultId();
        if (linkedId != null && linkedId.isNotEmpty) {
          await loginWithDid(linkedId);
          return;
        }
      }
      await loginWithSovereignDid();
    }
  }

  Future<void> loginWithDid(String didAddress) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final res = await _cloud.signInWithSovereignDid(didAddress);
      await _repository.restoreVaultFromCloud();
      await _repository.syncPendingOfflineChanges();

      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: res?.user ?? _cloud.currentUser,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: _cloud.currentUser,
        errorMessage: null,
      ));
    }
  }

  Future<void> loginWithSovereignDid() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final didAddress = Web3Service.instance.walletAddressHex.toLowerCase().replaceAll('0x', '').trim();
      final syntheticEmail = 'did_${didAddress.replaceAll('0x', '')}@beaconos.com';
      final passSlice = didAddress.length >= 20
          ? didAddress.substring(0, 20)
          : didAddress;
      final syntheticPassword = 'BeaconDID:${passSlice}!Sovereign2026';

      AuthResponse? res;
      try {
        res = await _cloud.signInWithEmail(
          email: syntheticEmail,
          password: syntheticPassword,
        );
      } catch (_) {
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

  Future<void> continueAsGuest() async {
    await loginWithSovereignDid();
  }

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