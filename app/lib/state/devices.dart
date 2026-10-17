import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import 'providers.dart';

/// What the "My devices" screen shows: the mesh as the core last reported it.
class DevicesState {
  const DevicesState({this.status, this.error, this.exitError, this.busyId, this.loading = true});

  /// The last answer; kept while a refresh fails, so the list does not blink away.
  final MeshStatus? status;

  /// The last failure to list the devices (null after a good answer).
  final Object? error;

  /// The last failure to switch the exit device (null after the next try).
  final Object? exitError;

  /// The device whose "use as exit" is being switched ('' while it is being cleared).
  final String? busyId;
  final bool loading;

  DevicesState copyWith({
    MeshStatus? status,
    Object? error,
    Object? exitError,
    bool clearExitError = false,
    String? busyId,
    bool clearBusy = false,
    bool? loading,
  }) => DevicesState(
    status: status ?? this.status,
    error: error ?? this.error,
    exitError: clearExitError ? null : exitError ?? this.exitError,
    busyId: clearBusy ? null : busyId ?? this.busyId,
    loading: loading ?? this.loading,
  );
}

/// Polls the core for the mesh's devices while the screen is open, and switches the exit device.
class DevicesController extends Notifier<DevicesState> {
  static const refreshEvery = Duration(seconds: 3);

  @override
  DevicesState build() {
    final timer = Timer.periodic(refreshEvery, (_) => refresh());
    ref.onDispose(timer.cancel);
    Future.microtask(refresh);
    return const DevicesState();
  }

  Future<void> refresh() async {
    if (!ref.mounted || state.busyId != null) return;
    try {
      final status = await ref.read(engineProvider).meshStatus();
      if (ref.mounted) state = DevicesState(status: status, exitError: state.exitError, loading: false);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e, loading: false);
    }
  }

  /// Sends all traffic out through the device [id], or back to the normal connection when [id] is empty.
  Future<void> useAsExit(String id) async {
    if (state.busyId != null) return;
    state = state.copyWith(busyId: id, clearExitError: true);
    try {
      final status = await ref.read(engineProvider).setMeshExit(id);
      if (ref.mounted) state = DevicesState(status: status, loading: false);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(exitError: e, clearBusy: true);
    }
  }
}

final devicesProvider = NotifierProvider.autoDispose<DevicesController, DevicesState>(DevicesController.new);
