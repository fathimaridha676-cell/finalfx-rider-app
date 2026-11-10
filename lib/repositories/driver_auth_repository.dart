import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/driver_profile_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final driverAuthRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return DriverAuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

class DriverAuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DriverAuthRepository(this._auth, this._firestore);

  /// Authenticates using Firebase Auth and resolves the driver's profile from Firestore
  Future<DriverProfileModel> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Sign in with Firebase Auth
    final userCred = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = userCred.user;
    if (user == null) {
      throw Exception('Authentication failed: user is null');
    }

    // 2. Locate Driver profile across Firestore
    final profile = await fetchDriverProfileByEmail(cleanEmail);
    if (profile == null) {
      // Sign out since user is not registered as a driver
      await _auth.signOut();
      throw Exception(
        'Account found, but you are not registered as an active delivery driver. Please contact your outlet manager.',
      );
    }

    if (!profile.isActive || profile.isDeleted) {
      await _auth.signOut();
      throw Exception(
        'Your driver account has been deactivated. Please contact your manager.',
      );
    }

    return profile;
  }

  /// Platform-aware Google Sign-In for Drivers
  Future<DriverProfileModel> loginWithGoogle() async {
    UserCredential userCred;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      userCred = await _auth.signInWithPopup(googleProvider);
    } else {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign-in-canceled',
          message: 'Google Sign-In canceled by user.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCred = await _auth.signInWithCredential(credential);
    }

    final user = userCred.user;
    if (user == null || user.email == null) {
      throw Exception('Failed to obtain user email from Google.');
    }

    final cleanEmail = user.email!.trim().toLowerCase();
    final profile = await fetchDriverProfileByEmail(cleanEmail);

    if (profile == null) {
      await _auth.signOut();
      throw Exception(
        'The Google account ($cleanEmail) is not registered as a delivery driver. Please contact your manager.',
      );
    }

    if (!profile.isActive || profile.isDeleted) {
      await _auth.signOut();
      throw Exception(
        'Your driver account has been deactivated. Please contact your manager.',
      );
    }

    return profile;
  }

  /// Locates driver profile by email using Firestore collectionGroup('riderUsers').
  /// Afterwards, it enriches the profile with the full OutletModel data
  /// (`nameAr`, `addressEn`/`addressAr`, `mobileNumber`) from Firestore.
  Future<DriverProfileModel?> fetchDriverProfileByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    DriverProfileModel? profile;

    try {
      final snapshot = await _firestore
          .collectionGroup('riderUsers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        profile = DriverProfileModel.fromMap(doc.data(), id: doc.id);
      }
    } catch (e) {
      debugPrint('[DriverAuthRepository] Error querying collectionGroup riderUsers: $e');
    }

    if (profile == null) return null;

    // Enrich profile with full Outlet details (nameAr, address, phone)
    try {
      final outletId = profile.outletId.trim();
      final brandId = profile.brandId.trim();

      if (outletId.isNotEmpty) {
        DocumentSnapshot<Map<String, dynamic>>? outletDoc;

        // Try /brands/{brandId}/outlets/{outletId}
        if (brandId.isNotEmpty) {
          try {
            final doc = await _firestore
                .collection('brands')
                .doc(brandId)
                .collection('outlets')
                .doc(outletId)
                .get();
            if (doc.exists && doc.data() != null) {
              outletDoc = doc;
            }
          } catch (_) {}
        }

        // Try collectionGroup('outlets') fallback if needed
        if (outletDoc == null || !outletDoc.exists) {
          try {
            final snap = await _firestore
                .collectionGroup('outlets')
                .where(FieldPath.documentId, isEqualTo: outletId)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              outletDoc = snap.docs.first;
            }
          } catch (_) {}
        }

        if (outletDoc != null && outletDoc.data() != null) {
          final oData = outletDoc.data()!;
          final enName = (oData['nameEn'] ?? oData['name'] ?? profile.outletName).toString();
          final arName = (oData['nameAr'] ?? '').toString();
          final addr = (oData['addressEn'] ?? oData['location'] ?? oData['address'] ?? profile.outletAddress).toString();
          final addrAr = (oData['addressAr'] ?? '').toString();
          final phone = (oData['mobileNumber'] ?? oData['phone'] ?? oData['contactPhone'] ?? profile.outletPhone).toString();

          profile = DriverProfileModel(
            id: profile.id,
            uid: profile.uid,
            name: profile.name,
            email: profile.email,
            mobileNumber: profile.mobileNumber,
            secondMobileNumber: profile.secondMobileNumber,
            outletId: profile.outletId,
            outletName: enName.isNotEmpty ? enName : profile.outletName,
            outletNameAr: arName.isNotEmpty ? arName : profile.outletNameAr,
            outletAddress: addr.isNotEmpty ? addr : profile.outletAddress,
            outletAddressAr: addrAr.isNotEmpty ? addrAr : profile.outletAddressAr,
            outletPhone: phone.isNotEmpty ? phone : profile.outletPhone,
            brandId: profile.brandId,
            brandName: profile.brandName,
            isActive: profile.isActive,
            isDeleted: profile.isDeleted,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
          );
        }
      }
    } catch (e) {
      debugPrint('[DriverAuthRepository] Error enriching outlet details: $e');
    }

    return profile;
  }

  /// Signs the driver out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

