import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/rider_orders_repository.dart';

final driverDutyStatusProvider = StateProvider<bool>((ref) => true);

final riderOrdersControllerProvider =
    StateNotifierProvider<RiderOrdersController, AsyncValue<void>>((ref) {
  final repo = ref.watch(riderOrdersRepositoryProvider);
  return RiderOrdersController(repo);
});

class RiderOrdersController extends StateNotifier<AsyncValue<void>> {
  final RiderOrdersRepository _repo;

  RiderOrdersController(this._repo) : super(const AsyncValue.data(null));

  Future<void> toggleDutyStatus({
    required String outletId,
    required String driverId,
    required bool isOnline,
    String? email,
  }) async {
    try {
      await _repo.updateDriverDutyStatus(
        outletId: outletId,
        driverId: driverId,
        isOnline: isOnline,
        email: email,
      );
    } catch (_) {}
  }

  Future<bool> markOrderDelivered({
    required String outletId,
    required String orderId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateDeliveryStatus(
        outletId: outletId,
        orderId: orderId,
        status: 'DELIVERED',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> cancelOrder({
    required String outletId,
    required String orderId,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateDeliveryStatus(
        outletId: outletId,
        orderId: orderId,
        status: 'CANCELLED',
        cancellationReason: reason,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> startDelivery({
    required String outletId,
    required String orderId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateDeliveryStatus(
        outletId: outletId,
        orderId: orderId,
        status: 'OUT_FOR_DELIVERY',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

