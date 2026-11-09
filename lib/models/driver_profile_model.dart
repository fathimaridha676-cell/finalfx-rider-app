import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// DRIVER PROFILE MODEL
/// ============================================================================
/// Represents the driver profile stored in Firestore.
/// Matches the schema from the admin portal under `/inventory/{outletId}/drivers`.
class DriverProfileModel {
  final String? id;
  final String? uid;
  final String name;
  final String email;
  final String mobileNumber;
  final String secondMobileNumber;
  final String outletId;
  final String outletName;
  final String outletNameAr;
  final String outletAddress;
  final String outletAddressAr;
  final String outletPhone;
  final String brandId;
  final String brandName;
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverProfileModel({
    this.id,
    this.uid,
    required this.name,
    required this.email,
    required this.mobileNumber,
    this.secondMobileNumber = '',
    required this.outletId,
    this.outletName = '',
    this.outletNameAr = '',
    this.outletAddress = '',
    this.outletAddressAr = '',
    this.outletPhone = '',
    this.brandId = '',
    this.brandName = '',
    this.isActive = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverProfileModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return DriverProfileModel(
      id: id ?? map['id'] as String?,
      uid: map['uid'] as String?,
      name: (map['name'] ?? map['driverName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      mobileNumber: (map['mobileNumber'] ?? map['phone'] ?? '') as String,
      secondMobileNumber: (map['secondMobileNumber'] ?? '') as String,
      outletId: (map['outletId'] ?? '') as String,
      outletName: (map['outletName'] ?? map['branchName'] ?? map['nameEn'] ?? '') as String,
      outletNameAr: (map['outletNameAr'] ?? map['branchNameAr'] ?? map['nameAr'] ?? '') as String,
      outletAddress: (map['outletAddress'] ?? map['address'] ?? map['addressEn'] ?? '') as String,
      outletAddressAr: (map['outletAddressAr'] ?? map['addressAr'] ?? '') as String,
      outletPhone: (map['outletPhone'] ?? map['branchPhone'] ?? map['phone'] ?? map['mobileNumber'] ?? '') as String,
      brandId: (map['brandId'] ?? '') as String,
      brandName: (map['brandName'] ?? '') as String,
      isActive: (map['isActive'] ?? true) as bool,
      isDeleted: (map['isDeleted'] ?? false) as bool,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (uid != null) 'uid': uid,
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'secondMobileNumber': secondMobileNumber,
      'outletId': outletId,
      'outletName': outletName,
      'brandId': brandId,
      'brandName': brandName,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

