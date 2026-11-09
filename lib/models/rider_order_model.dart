import 'package:cloud_firestore/cloud_firestore.dart';

class RiderOrderModel {
  final String id;
  final String orderNumber;
  final int orderSequence;
  final String outletId;
  final String outletName;
  final String brandId;
  final String brandName;
  final String orderStatus; // PENDING, PROCESSING, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
  final String paymentMethod;
  final String paymentMethodLabel;
  final String paymentStatus;
  final double totalAmount;
  final double deliveryFee;
  final String source;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerNotes;
  final List<RiderOrderItem> items;
  final DateTime createdDate;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final DateTime? assignedDriverAt;
  final String? cancellationReason;
  final String? cancelledBy;

  const RiderOrderModel({
    required this.id,
    required this.orderNumber,
    this.orderSequence = 0,
    required this.outletId,
    this.outletName = '',
    this.brandId = '',
    this.brandName = '',
    required this.orderStatus,
    this.paymentMethod = 'PAY_LATER',
    this.paymentMethodLabel = 'Pay upon Delivery',
    this.paymentStatus = 'PENDING',
    this.totalAmount = 0.0,
    this.deliveryFee = 0.0,
    this.source = 'DIGITAL_MENU',
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerNotes = '',
    required this.items,
    required this.createdDate,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverAt,
    this.cancellationReason,
    this.cancelledBy,
  });

  factory RiderOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RiderOrderModel.fromMap(data, doc.id);
  }

  factory RiderOrderModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final effectiveId = (docId != null && docId.isNotEmpty)
        ? docId
        : (map['orderId']?.toString() ?? map['orderNumber']?.toString() ?? '');

    // Parse items
    final rawItems = map['items'];
    final itemsList = <RiderOrderItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          itemsList.add(RiderOrderItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Parse customer
    String cName = 'Guest Customer';
    String cPhone = '';
    String cAddress = '';
    String cNotes = '';

    if (map['customer'] is Map) {
      final cMap = Map<String, dynamic>.from(map['customer'] as Map);
      cName = cMap['name']?.toString() ?? cMap['fullName']?.toString() ?? 'Customer';
      cPhone = cMap['phone']?.toString() ?? cMap['phoneNumber']?.toString() ?? '';
      cAddress = cMap['address']?.toString() ?? cMap['deliveryAddress']?.toString() ?? '';
      cNotes = cMap['notes']?.toString() ?? '';
    } else {
      cName = map['customerName']?.toString() ?? 'Customer';
      cPhone = map['customerPhone']?.toString() ?? '';
      cAddress = map['deliveryAddress']?.toString() ?? map['address']?.toString() ?? '';
    }

    // Parse date
    DateTime parsedDate;
    final rawDate = map['createdDate'] ?? map['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      parsedDate = DateTime.now();
    }

    return RiderOrderModel(
      id: effectiveId,
      orderNumber: map['orderNumber']?.toString() ?? effectiveId,
      orderSequence: (map['orderSequence'] as num?)?.toInt() ?? 0,
      outletId: map['outletId']?.toString() ?? '',
      outletName: map['outletName']?.toString() ?? '',
      brandId: map['brandId']?.toString() ?? '',
      brandName: map['brandName']?.toString() ?? '',
      orderStatus: map['orderStatus']?.toString() ?? 'PENDING',
      paymentMethod: map['paymentMethod']?.toString() ?? 'PAY_LATER',
      paymentMethodLabel: map['paymentMethodLabel']?.toString() ?? 'Pay upon Delivery',
      paymentStatus: map['paymentStatus']?.toString() ?? 'PENDING',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      source: map['source']?.toString() ?? 'DIGITAL_MENU',
      customerName: cName,
      customerPhone: cPhone,
      customerAddress: cAddress,
      customerNotes: cNotes,
      items: itemsList,
      createdDate: parsedDate,
      assignedDriverId: map['assignedDriverId']?.toString() ?? map['driverId']?.toString(),
      assignedDriverName: map['assignedDriverName']?.toString() ?? map['driverName']?.toString(),
      cancellationReason: map['cancellationReason']?.toString(),
      cancelledBy: map['cancelledBy']?.toString(),
    );
  }
}

class RiderOrderItem {
  final String name;
  final int qty;
  final double price;
  final String? variant;

  const RiderOrderItem({
    required this.name,
    required this.qty,
    required this.price,
    this.variant,
  });

  factory RiderOrderItem.fromMap(Map<String, dynamic> map) {
    return RiderOrderItem(
      name: map['name']?.toString() ?? 'Item',
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      variant: map['selectedColor']?.toString() ?? map['selectedSubVariant']?.toString(),
    );
  }
}

