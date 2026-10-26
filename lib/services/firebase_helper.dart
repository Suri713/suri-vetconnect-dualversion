import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:vetconnect/services/nearby_business_search.dart';
import 'package:vetconnect/services/business_directory_entry.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:device_info_plus/device_info_plus.dart';

class _FirebaseUser {
  final String _userId;
  final String? _email;
  String? _userName;
  LatLng? _location;
  String? _photoUrl;
  final bool _anonymous;

  _FirebaseUser(
    this._userId,
    this._userName,
    this._email,
    this._photoUrl, {
    bool anonymous = false,
  }) : _anonymous = anonymous;

  String get userId => _userId;
  String? get userName => _userName;
  String? get email => _email;
  LatLng? get location => _location;
  String? get photoUrl => _photoUrl;
  bool get anonymous => _anonymous;

  set userName(String userName) {
    _userName = userName;
  }

  set location(LatLng location) {
    _location = location;
  }

  set photoUrl(String photoUrl) {
    _photoUrl = photoUrl;
  }
}

class FirebaseHelper {
  static final directoryRevision = ValueNotifier<int>(0);
  final _FirebaseUser _firebaseUser;
  final FirebaseAuth _auth;
  final FirebaseFirestore _store;
  AccountPathway? _pathway;
  AccountPathway? get pathway => anonymous ? AccountPathway.user : _pathway;
  bool get canManageBusiness => !anonymous && pathway == AccountPathway.veteran;

  String get userId => _firebaseUser.userId;
  String? get userName => _firebaseUser.userName;
  String? get email => _firebaseUser.email;
  LatLng? get location => _firebaseUser.location;
  bool get anonymous => _firebaseUser.anonymous;

  FirebaseHelper._(
    this._firebaseUser, {
    FirebaseAuth? auth,
    FirebaseFirestore? store,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _store = store ?? FirebaseFirestore.instance;

  Future<bool> setPathway(AccountPathway pathway) async {
    if (anonymous || !_hasWriteAccess()) return false;
    final saved = await _placeData('users', userId, {
      'accountPathway': pathway.value,
    });
    if (saved) _pathway = pathway;
    return saved;
  }

  Future<void> _loadPathway() async {
    final snapshot = await _store.collection('users').doc(userId).get();
    _pathway = AccountPathway.fromValue(snapshot.data()?['accountPathway']);
    _firebaseUser._userName =
        snapshot.data()?['userName'] as String? ?? _firebaseUser.userName;
  }

  bool _hasWriteAccess() {
    if (anonymous) {
      return false;
    }

    return userId == _auth.currentUser?.uid;
  }

  Future<bool> setUserName(String userName) async {
    try {
      final cleanedName = userName.trim();
      if (cleanedName.isEmpty) {
        return false;
      }

      if (!_hasWriteAccess()) return false;
      final saved = await _placeData("users", userId, {
        "userName": cleanedName,
      });
      if (saved) _firebaseUser.userName = cleanedName;
      return saved;
    } catch (e) {
      debugPrint("Unable to set user name: $e");
      return false;
    }
  }

  Future<bool> setUserLocation(LatLng location) async {
    try {
      if (!_hasWriteAccess()) return false;
      final saved = await _placeData("users", userId, {
        "lat": location.latitude,
        "lng": location.longitude,
      });
      if (saved) _firebaseUser.location = location;
      return saved;
    } catch (e) {
      debugPrint("Unable to set user location: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    return await _getData("users", userId);
  }

  Future<bool> saveBusiness(Map<String, dynamic> businessData) async {
    if (!_hasWriteAccess() || !canManageBusiness) return false;
    try {
      final entry = publicBusinessEntry(businessData, userId);
      // Existing rules allow owners to write their users document and everyone
      // to read it for discovery. All discovery queries below include users.
      await _store.collection('users').doc(userId).set(
        {
          'businessName': businessData['name'],
          'business': entry['business'],
          'businessSearchPrefixes': entry['searchPrefixes'],
        },
        SetOptions(
          mergeFields: ['businessName', 'business', 'businessSearchPrefixes'],
        ),
      );
      directoryRevision.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBusiness(String userId) async {
    Map<String, dynamic>? userData = await _getData("users", userId);

    if (userData == null) {
      return {};
    }

    return userData["business"] as Map<String, dynamic>?;
  }

  Future<bool> deleteBusiness() async {
    if (!_hasWriteAccess() || !canManageBusiness) return false;
    try {
      await _store.collection('users').doc(userId).set({
        'business': FieldValue.delete(),
        'businessName': FieldValue.delete(),
        'businessSearchPrefixes': FieldValue.delete(),
      }, SetOptions(merge: true));
      directoryRevision.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>?>> searchForBusiness(
    String queryString, {
    LatLng? location,
  }) async {
    final cleanQuery = queryString.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return [];
    }

    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(30)
        .toList();
    if (words.isEmpty) {
      return [];
    }

    try {
      final snapshots = await Future.wait([
        _store
            .collection('known_businesses')
            .where('searchPrefixes', arrayContainsAny: words)
            .limit(20)
            .get(),
        _store
            .collection('users')
            .where('businessSearchPrefixes', arrayContainsAny: words)
            .limit(20)
            .get(),
      ]).timeout(const Duration(seconds: 12));
      final businesses = _businessesFrom(
        snapshots.expand((snapshot) => snapshot.docs),
      );

      if (location == null) {
        return businesses;
      }

      const distance = Distance();
      for (final business in businesses) {
        final lat = business["lat"];
        final lng = business["lng"];
        if (lat is num && lng is num) {
          business["distanceMiles"] = distance.as(
            LengthUnit.Mile,
            location,
            LatLng(lat.toDouble(), lng.toDouble()),
          );
        }
      }

      businesses.sort((a, b) {
        final aDistance =
            (a["distanceMiles"] as num?)?.toDouble() ?? double.infinity;
        final bDistance =
            (b["distanceMiles"] as num?)?.toDouble() ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });

      return businesses;
    } catch (e) {
      debugPrint("Unable to complete search: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchBusinessesWithinRadius(
    String query,
    LatLng center,
  ) async {
    // A single-field latitude range needs no custom composite index. Paging
    // avoids discarding nearby matches behind the old nationwide 20-item cap.
    const radiusMiles = 20.0;
    final delta =
        radiusMiles / 68.0; // Broad bounds, then exact distance below.
    final candidates = <Map<String, dynamic>>[];
    for (final collection in ['known_businesses', 'users']) {
      final base = _store
          .collection(collection)
          .where(
            'business.lat',
            isGreaterThanOrEqualTo: max(-90, center.latitude - delta),
          )
          .where(
            'business.lat',
            isLessThanOrEqualTo: min(90, center.latitude + delta),
          )
          .orderBy('business.lat');
      QueryDocumentSnapshot<Map<String, dynamic>>? last;
      while (true) {
        final page = await (last == null ? base : base.startAfterDocument(last))
            .limit(200)
            .get()
            .timeout(const Duration(seconds: 12));
        candidates.addAll(_businessesFrom(page.docs));
        if (page.docs.length < 200) break;
        last = page.docs.last;
      }
    }
    return nearbyBusinessMatches(candidates, query, center);
  }

  Future<List<Map<String, dynamic>?>> findBusinessesByLocation(
    LatLng location, {
    int count = 20,
    int milesRadius = 10,
  }) async {
    try {
      final latDelta = milesRadius / 69.0;
      final lngDelta =
          milesRadius / (69.0 * cos(location.latitude * pi / 180.0));

      final snapshot = await _store
          .collection("users")
          .where(
            'business.lat',
            isGreaterThanOrEqualTo: location.latitude - latDelta,
          )
          .where(
            'business.lat',
            isLessThanOrEqualTo: location.latitude + latDelta,
          )
          .where(
            'business.lng',
            isGreaterThanOrEqualTo: location.longitude - lngDelta,
          )
          .where(
            'business.lng',
            isLessThanOrEqualTo: location.longitude + lngDelta,
          )
          .limit(200)
          .get();

      const distance = Distance();
      final List<Map<String, dynamic>> nearbyBusinesses = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data["business"] is! Map<String, dynamic>) {
          continue;
        }

        final business = Map<String, dynamic>.from(data["business"]);
        final businessLat = business["lat"];
        final businessLng = business["lng"];

        if (businessLat is! num || businessLng is! num) {
          continue;
        }

        final businessLocation = LatLng(
          businessLat.toDouble(),
          businessLng.toDouble(),
        );
        final miles = distance.as(LengthUnit.Mile, location, businessLocation);

        if (miles <= milesRadius) {
          business["distanceMiles"] = miles;
          nearbyBusinesses.add(business);
        }
      }

      nearbyBusinesses.sort((a, b) {
        final aDistance = (a["distanceMiles"] as num).toDouble();
        final bDistance = (b["distanceMiles"] as num).toDouble();
        return aDistance.compareTo(bDistance);
      });

      return nearbyBusinesses.take(count).toList();
    } catch (e) {
      debugPrint("Unable to complete search: $e");
      return [];
    }
  }

  List<Map<String, dynamic>> _businessesFrom(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final doc in docs) {
      final value = doc.data()['business'];
      if (value is! Map<String, dynamic>) continue;
      final business = Map<String, dynamic>.from(value);
      business['id'] ??= doc.reference.path;
      if (seen.add(business['id'].toString())) result.add(business);
    }
    return result;
  }

  /// Businesses located in any of [zips].
  ///
  /// The map uses this instead of [getAllBusinesses]. The directory only
  /// locates listings to a ZIP, so querying by ZIP asks the data exactly what
  /// it knows -- and because Firestore bills per document read, fetching the
  /// handful of ZIPs around the user costs a fraction of reading every
  /// listing on every map open.
  ///
  /// `whereIn` accepts at most 30 values, so longer lists are chunked into
  /// separate queries and merged.
  Future<List<Map<String, dynamic>>> getBusinessesByZips(
    List<String> zips, {
    int limitPerChunk = 200,
  }) async {
    if (zips.isEmpty) return [];

    const int whereInLimit = 30;
    final List<Map<String, dynamic>> businesses = [];
    final Set<String> seenIds = {};

    try {
      for (var start = 0; start < zips.length; start += whereInLimit) {
        final chunk = zips.sublist(
          start,
          min(start + whereInLimit, zips.length),
        );

        final snapshots = await Future.wait([
          for (final collection in ['known_businesses', 'users'])
            _store
                .collection(collection)
                .where('business.postalCode', whereIn: chunk)
                .limit(limitPerChunk)
                .get(),
        ]).timeout(const Duration(seconds: 12));
        for (final business in _businessesFrom(
          snapshots.expand((snapshot) => snapshot.docs),
        )) {
          if (seenIds.add(business['id'].toString())) businesses.add(business);
        }
      }
    } catch (e) {
      debugPrint("Unable to fetch businesses by ZIP: $e");
      rethrow;
    }

    return businesses;
  }

  /// Keyword search restricted to [zips].
  ///
  /// Firestore rejects a query combining `arrayContainsAny` (the keyword
  /// index) with `whereIn` (the ZIP list), so this fetches the ZIP-scoped
  /// businesses and matches the keyword in memory. That set is small -- the
  /// ZIPs around one point -- so the filtering is cheap and, unlike the
  /// global keyword search, it is not capped at 20 results.
  ///
  /// Matching mirrors [searchForBusiness]: a business qualifies if it matches
  /// any word in the query, and results are ordered by how many matched.
  Future<List<Map<String, dynamic>>> searchBusinessesInZips(
    String queryString,
    List<String> zips,
  ) async {
    final words = queryString
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(30)
        .toList();

    final businesses = await getBusinessesByZips(zips);
    if (words.isEmpty) return businesses;

    final scored = <MapEntry<Map<String, dynamic>, int>>[];
    for (final business in businesses) {
      final haystack =
          '${business["name"] ?? ''} ${business["description"] ?? ''}'
              .toLowerCase();

      var matched = 0;
      for (final word in words) {
        if (haystack.contains(word)) matched++;
      }
      if (matched > 0) scored.add(MapEntry(business, matched));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((entry) => entry.key).toList();
  }

  /// Reads every business in the directory.
  ///
  /// Cheap at the current size, but it scales with the whole collection --
  /// prefer [getBusinessesByZips] for anything map-shaped.
  Future<List<Map<String, dynamic>?>> getAllBusinesses() async {
    try {
      final snapshots = await Future.wait([
        for (final collection in ['known_businesses', 'users'])
          _store.collection(collection).get(),
      ]).timeout(const Duration(seconds: 12));
      final businesses =
          _businessesFrom(snapshots.expand((snapshot) => snapshot.docs))
              .where(
                (business) => business['lat'] is num && business['lng'] is num,
              )
              .toList();

      return businesses;
    } catch (e) {
      debugPrint("Unable to fetch businesses: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getConservationJobs() async {
    try {
      final snapshot = await _store
          .collection("conservation_jobs")
          .get()
          .timeout(const Duration(seconds: 12));

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Unable to fetch conservation jobs: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getData(
    String collection,
    String documentId,
  ) async {
    try {
      DocumentSnapshot doc = await _store
          .collection(collection)
          .doc(documentId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (error) {
      debugPrint("Error: $error");
      return null;
    }
  }

  Future<bool> _placeData(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _store
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: true));
      return true;
    } catch (error) {
      debugPrint("Error: $error");
      return false;
    }
  }

  static Future<FirebaseHelper?> register(
    String email,
    String password, {
    required AccountPathway pathway,
    FirebaseAuth? auth,
    FirebaseFirestore? store,
  }) async {
    try {
      final client = auth ?? FirebaseAuth.instance;
      final credential = await client.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final helper = FirebaseHelper._(
        _FirebaseUser(user.uid, user.displayName, user.email, user.photoURL),
        auth: client,
        store: store,
      );
      await helper.setPathway(pathway);
      return helper;
    } catch (_) {
      return null;
    }
  }

  static Future<FirebaseHelper?> login(
    String email,
    String password, {
    FirebaseAuth? auth,
    FirebaseFirestore? store,
  }) async {
    try {
      final client = auth ?? FirebaseAuth.instance;
      final credential = await client.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final helper = FirebaseHelper._(
        _FirebaseUser(user.uid, user.displayName, user.email, user.photoURL),
        auth: client,
        store: store,
      );
      await helper._loadPathway();
      return helper;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      if (!anonymous) {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          return false;
        }

        await _store.collection('users').doc(userId).delete();
        directoryRevision.value++;
        await currentUser.delete();
        return true;
      } else {
        return false;
      }
    } catch (error) {
      debugPrint("Error: $error");
      return false;
    }
  }

  static Future<FirebaseHelper?> anonymousEntry() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (Platform.isIOS) {
        var iOSDeviceInfo = await deviceInfo.iosInfo;
        deviceId = iOSDeviceInfo.identifierForVendor!;
      } else if (Platform.isAndroid) {
        var androidDeviceInfo = await deviceInfo.androidInfo;
        deviceId = androidDeviceInfo.fingerprint;
      } else {
        return null;
      }

      return FirebaseHelper._(
        _FirebaseUser(deviceId, null, null, null, anonymous: true),
      );
    } catch (error) {
      debugPrint("Error: $error");
      return null;
    }
  }

  Future<String?> setImage(File file) async {
    try {
      final String fileName = file.path.split('/').last;
      final String storagePath =
          'images/$userId/${DateTime.now().microsecondsSinceEpoch}_$fileName';

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        storagePath,
      );
      final UploadTask uploadTask = storageRef.putFile(file);

      final TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Unable to upload image: $e");
      return null;
    }
  }

  Future<void> deleteUploadedImage(String url) async {
    await FirebaseStorage.instance.refFromURL(url).delete();
  }
}
