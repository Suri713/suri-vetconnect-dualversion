import 'dart:io';
import 'package:vetconnect/services/account_pathway.dart';

import 'package:latlong2/latlong.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/services/business_photo_upload.dart';

class _Business {
  final String? _id;
  final String? _startDate;
  String? _name;
  String? _description;
  LatLng? _location;
  List<String> _photoUrls;
  String postalCode;
  String address;

  _Business(
    this._name,
    this._id,
    this._startDate,
    this._location,
    this._description,
    this._photoUrls,
    this.postalCode,
    this.address,
  );

  String? get name => _name;
  String? get id => _id;
  String? get startDate => _startDate;
  String? get description => _description;
  LatLng? get location => _location;
  List<String> get photoUrls => _photoUrls;

  set name(String name) {
    _name = name;
  }

  set location(LatLng location) {
    _location = location;
  }

  set description(String description) {
    _description = description;
  }

  set photoUrls(List<String> photoUrls) {
    _photoUrls = photoUrls;
  }
}

class BusinessHandler {
  _Business? _userBusiness;

  String? get name => _userBusiness?._name;
  String get postalCode => _userBusiness?.postalCode ?? "";
  String get address => _userBusiness?.address ?? "";
  String? get id => _userBusiness?._id;
  String? get startDate => _userBusiness?._startDate;
  String? get description => _userBusiness?._description;
  LatLng? get location => _userBusiness?._location;

  List<String> get photoUrls =>
      List.unmodifiable(_userBusiness?.photoUrls ?? []);

  BusinessHandler._(this._userBusiness);

  static Future<BusinessHandler?> init() async {
    try {
      _Business? userBusiness = await getBusiness(
        Constants.firebaseHelper.userId,
      );

      return BusinessHandler._(userBusiness);
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  Future<bool> createBusiness(
    String name,
    String startDate,
    LatLng? location,
    String description, {
    List<File> photos = const <File>[],
    bool replaceExisting = false,
    required String dodId,
    required String postalCode,
    String address = "",
  }) async {
    try {
      if (!Constants.firebaseHelper.canManageBusiness ||
          !isValidDodId(dodId) ||
          !RegExp(r'^[0-9]{5}$').hasMatch(postalCode))
        return false;
      if (!replaceExisting &&
          _userBusiness != null &&
          await Constants.firebaseHelper.getBusiness(
                Constants.firebaseHelper.userId,
              ) !=
              null) {
        print("User already has a business.");
        return false;
      }

      if (name.length == 0 || startDate.length == 0 || location == null) {
        print("Invaild name or location.");
        return false;
      }

      final id = Constants.uuid.v4();
      final uploaded = await BusinessPhotoUpload.save(
        photos,
        uploadFile: Constants.firebaseHelper.setImage,
        deleteFile: Constants.firebaseHelper.deleteUploadedImage,
        commit: (urls) => Constants.firebaseHelper.saveBusiness({
          'id': id,
          'name': name,
          'startDate': startDate,
          'lat': location.latitude,
          'lng': location.longitude,
          'description': description.trim(),
          'photoUrls': urls,
          'postalCode': postalCode,
          'address': address.trim(),
          'ownershipStatus': 'selfReported',
        }),
      );
      // Publish the new in-memory profile only after the full save succeeds.
      _userBusiness = _Business(
        name,
        id,
        startDate,
        location,
        description.trim(),
        uploaded,
        postalCode,
        address.trim(),
      );
      return true;
    } catch (e) {
      print("Unable to create new business.");
      return false;
    }
  }

  Future<bool> updateBusiness(
    String name,
    LatLng? location,
    String description, {
    required String postalCode,
  }) async {
    try {
      if (!Constants.firebaseHelper.canManageBusiness ||
          !RegExp(r'^[0-9]{5}$').hasMatch(postalCode) ||
          name.isEmpty ||
          location == null ||
          !location.latitude.isFinite ||
          !location.longitude.isFinite ||
          location.latitude.abs() > 90 ||
          location.longitude.abs() > 180) {
        print("Invaild name or location.");
        return false;
      }

      final previous = _userBusiness;
      if (previous == null) return false;
      _userBusiness = _Business(
        previous.name,
        previous.id,
        previous.startDate,
        previous.location,
        previous.description,
        previous.photoUrls,
        previous.postalCode,
        previous.address,
      );
      if (previous.location != location) _userBusiness!.address = '';
      _userBusiness?.postalCode = postalCode;
      _userBusiness?._name = name;
      _userBusiness?._location = location;
      _userBusiness?._description = description.trim();

      final saved = await save();
      if (!saved) _userBusiness = previous;
      return saved;
    } catch (e) {
      print("Unable to update business: $e");
      return false;
    }
  }

  Future<bool> save() async {
    Map<String, dynamic> data = {
      "name": _userBusiness?.name,
      "postalCode": postalCode,
      "address": address,
      "ownershipStatus": "selfReported",
      "id": _userBusiness?.id,
      "startDate": _userBusiness?.startDate,
      "description": _userBusiness?.description ?? "",
      "photoUrls": _userBusiness?.photoUrls ?? <String>[],
      "lat": _userBusiness?.location!.latitude ?? 0.0,
      "lng": _userBusiness?.location!.longitude ?? 0.0,
    };

    if (await Constants.firebaseHelper.saveBusiness(data)) {
      print("Backed up business data");
      return true;
    } else {
      print("Unable to backup business data.");
      return false;
    }
  }

  static Future<_Business?> getBusiness(String userId) async {
    try {
      Map<String, dynamic> businessData =
          await Constants.firebaseHelper.getBusiness(userId) ?? {};

      if (businessData.isEmpty) {
        return null;
      }

      if (!businessData.containsKey("name") ||
          !businessData.containsKey("id") ||
          !businessData.containsKey("startDate") ||
          !businessData.containsKey("lat") ||
          !businessData.containsKey("lng")) {
        print("User has incomplete business data.");
        return null;
      }

      final LatLng location = LatLng(
        (businessData["lat"] as num).toDouble(),
        (businessData["lng"] as num).toDouble(),
      );
      final String description = businessData["description"]?.toString() ?? "";

      return _Business(
        businessData["name"],
        businessData["id"],
        businessData["startDate"],
        location,
        description,
        (businessData['photoUrls'] as List? ?? []).whereType<String>().toList(),
        businessData['postalCode']?.toString() ?? '',
        businessData['address']?.toString() ?? '',
      );
    } catch (e) {
      print("Unable to get business data: $e");
      return null;
    }
  }

  // TODO: implement
  Future<bool> deleteBusiness() async {
    try {
      if (_userBusiness == null) {
        print("No business exists to delete.");
        return false;
      }

      final success = await Constants.firebaseHelper.deleteBusiness();
      if (!success) {
        print("Unable to delete business data from storage.");
        return false;
      }

      _userBusiness = null;
      return true;
    } catch (e) {
      print("Unable to delete business: $e");
      return false;
    }
  }
}
