import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rider_order_model.dart';
import '../models/driver_profile_model.dart';
import 'driver_auth_repository.dart';

final riderOrdersRepositoryProvider = Provider<RiderOrdersRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return RiderOrdersRepository(firestore);
});

/// Streams all orders assigned to a specific driver
final driverOrdersStreamProvider =
    StreamProvider.family<List<RiderOrderModel>, DriverProfileModel>((ref, driver) {
  final repo = ref.watch(riderOrdersRepositoryProvider);
  return repo.streamOrdersForDriver(driver);
});

class RiderOrdersRepository {
  final FirebaseFirestore _firestore;

  RiderOrdersRepository(this._firestore);

  /// Streams real-time orders assigned to this driver.
  /// Matches on assignedDriverId, driver.id, driver.uid, or driver.email
  Stream<List<RiderOrderModel>> streamOrdersForDriver(DriverProfileModel driver) {
    final cleanEmail = driver.email.trim().toLowerCase();
    final driverId = driver.id?.trim() ?? '';
    final driverUid = driver.uid?.trim() ?? '';
    final outletId = driver.outletId.trim();

    debugPrint('[RiderOrdersRepository] Listening for orders -> outletId: "$outletId", driverId: "$driverId", uid: "$driverUid", email: "$cleanEmail"');

    // We listen to the outlet's digitalMenuOrders subcollection
    return _firestore
        .collection('orders')
        .doc(outletId)
        .collection('digitalMenuOrders')
        .snapshots()
        .map((snapshot) {
          debugPrint('[RiderOrdersRepository] Snapshot received with ${snapshot.docs.length} total orders in outlet "$outletId"');
          final list = <RiderOrderModel>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final assignedId = data['assignedDriverId']?.toString().trim();
            final fallbackDriverId = data['driverId']?.toString().trim();
            final assignedEmail = data['assignedDriverEmail']?.toString().trim().toLowerCase();
            final assignedPhone = data['assignedDriverPhone']?.toString().trim();

            bool isAssigned = false;

            if (driverId.isNotEmpty && (assignedId == driverId || fallbackDriverId == driverId)) {
              isAssigned = true;
            } else if (driverUid.isNotEmpty && (assignedId == driverUid || fallbackDriverId == driverUid)) {
              isAssigned = true;
            } else if (cleanEmail.isNotEmpty && assignedEmail == cleanEmail) {
              isAssigned = true;
            } else if (driver.mobileNumber.isNotEmpty && assignedPhone == driver.mobileNumber) {
              isAssigned = true;
            }

            if (isAssigned) {
              debugPrint('[RiderOrdersRepository] Matched assigned order: ${doc.id} (Order #${data['orderNumber']})');
              list.add(RiderOrderModel.fromFirestore(doc));
            }
          }

          list.sort((a, b) {
            final dateA = a.assignedDriverAt ?? a.createdDate;
            final dateB = b.assignedDriverAt ?? b.createdDate;
            return dateB.compareTo(dateA);
          });
          return list;
        });
  }

  /// Updates driver online/offline duty status in Firestore across all relevant locations
  Future<void> updateDriverDutyStatus({
    required String outletId,
    required String driverId,
    required bool isOnline,
    String? email,
  }) async {
    final statusMap = <String, dynamic>{
      'isOnline': isOnline,
      'dutyStatus': isOnline ? 'online' : 'offline',
      'lastDutyChangedAt': FieldValue.serverTimestamp(),
    };

    // 1. Update in /riderUsers/{outletId}/riderUsers/{driverId}
    if (outletId.isNotEmpty && driverId.isNotEmpty) {
      try {
        final docRef = _firestore
            .collection('riderUsers')
            .doc(outletId)
            .collection('riderUsers')
            .doc(driverId);
        
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          await docRef.update(statusMap);
          return;
        }
      } catch (e) {
        debugPrint('[RiderOrdersRepository] Error updating /riderUsers/$outletId/riderUsers/$driverId: $e');
      }
    }

    // 2. Fallback search by email if driverId was not matched directly
    if (outletId.isNotEmpty && email != null && email.isNotEmpty) {
      try {
        final querySnap = await _firestore
            .collection('riderUsers')
            .doc(outletId)
            .collection('riderUsers')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .get();

        for (final doc in querySnap.docs) {
          await doc.reference.update(statusMap);
        }
      } catch (e) {
        debugPrint('[RiderOrdersRepository] Error updating by email query: $e');
      }
    }
  }

  /// Updates order delivery status (e.g. SHOP_PICKED, OUT_FOR_DELIVERY, ARRIVED, DELIVERED)
  /// If status is ARRIVED and no OTP exists in doc, generates a random 4-digit PIN for customer verification.
  Future<String?> updateDeliveryStatus({
    required String outletId,
    required String orderId,
    required String status,
    String? cancellationReason,
    String? generatedOtp,
  }) async {
    final updateData = <String, dynamic>{
      'orderStatus': status,
      'status': status == 'CANCELLED' ? -1 : 1,
      if (status == 'SHOP_PICKED' || status == 'PICKED_FROM_SHOP')
        'pickedAt': FieldValue.serverTimestamp(),
      if (status == 'OUT_FOR_DELIVERY' || status == 'DISPATCHED')
        'dispatchedAt': FieldValue.serverTimestamp(),
      if (status == 'ARRIVED') ...{
        'arrivedAt': FieldValue.serverTimestamp(),
        // If an OTP was passed (or generated), persist it to Firestore so the customer app can display it
        if (generatedOtp != null && generatedOtp.isNotEmpty) 'deliveryOtp': generatedOtp,
      },
      if (status == 'DELIVERED') 'deliveredAt': FieldValue.serverTimestamp(),
      if (status == 'CANCELLED') ...{
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'RIDER',
        'cancellationReason': cancellationReason ?? 'Cancelled by delivery driver',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('orders')
        .doc(outletId)
        .collection('digitalMenuOrders')
        .doc(orderId)
        .set(updateData, SetOptions(merge: true));

    return generatedOtp;
  }

  /// Completes delivery and marks payment as collected
  Future<void> completeDeliveryWithPayment({
    required String outletId,
    required String orderId,
    required Map<String, double> paymentBreakdown,
    required String primaryPaymentMethod,
  }) async {
    final updateData = <String, dynamic>{
      'orderStatus': 'DELIVERED',
      'paymentStatus': 'PAID',
      'paymentMethod': primaryPaymentMethod,
      'collectedPaymentBreakdown': paymentBreakdown,
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('orders')
        .doc(outletId)
        .collection('digitalMenuOrders')
        .doc(orderId)
        .set(updateData, SetOptions(merge: true));
  }
}

