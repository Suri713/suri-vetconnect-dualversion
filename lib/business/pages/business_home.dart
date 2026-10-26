import 'dart:math' as math;
import 'package:vetconnect/services/firebase_helper.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:vetconnect/services/nearby_business_search.dart';
import 'package:vetconnect/services/business_recommendations.dart';
import 'package:vetconnect/business/widgets/business_interests_sheet.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vetconnect/business/pages/business_search.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/business/widgets/business_photo_gallery.dart';
import 'package:vetconnect/business/widgets/business_directions_button.dart';
import 'package:vetconnect/services/business_directions.dart';
import 'package:vetconnect/services/zip_service.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class BusinessHome extends StatefulWidget {
  const BusinessHome({super.key});

  @override
  State<BusinessHome> createState() => _BusinessHomeState();
}

class _BusinessHomeState extends State<BusinessHome> {
  static const LatLng _defaultCenter = LatLng(39.8283, -98.5795);
  static const double _sheetPeekSize = 0.19;
  static const double _sheetExpandedSize = 0.65;
  static const double _sheetMaxSize = 0.7;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  GoogleMapController? _mapController;
  Marker? _userMarker;
  Set<Marker> _businessMarkers = {};

  /// Markers for the current keyword search.
  ///
  /// Search spans the whole directory, but the map only loads the ZIPs around
  /// the user -- so a hit in another state has no marker unless we add one
  /// here. Without this, tapping a result flies the camera to an empty map.
  Set<Marker> _searchMarkers = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _loadedBusinesses = [];
  RecommendationProfile? _recommendationProfile;
  bool _isInitializing = true;
  bool _businessLoadFailed = false;
  int _loadRequestId = 0;
  List<String> _retryZips = const [];
  String? _retryZipLabel;

  /// Most ZIPs to send in one lookup. Firestore's whereIn caps at 30 values,
  /// and a dense metro can otherwise return hundreds of nearby ZIPs.
  static const int _zipQueryLimit = 30;

  final TextEditingController _zipController = TextEditingController();
  ZipService? _zipService;
  String? _activeZip;
  int _loadedZipCount = 0;
  int _loadedBusinessCount = 0;
  bool _isLoadingBusinesses = false;
  bool _needsZip = true;

  /// When on, a keyword search is limited to the ZIPs currently loaded;
  /// when off, it covers the whole directory.
  bool _limitSearchToArea = false;
  List<String> _loadedZips = const [];

  CameraPosition? _lastCameraPosition;
  LatLng? _loadedCenter;
  double _loadedRadiusMiles = _defaultRadiusMiles;

  static const double _defaultRadiusMiles = 10;

  /// Zooming out is how people ask to see a wider area, so widen the ZIP
  /// search to match instead of leaving the same handful of pins on screen.
  static double _radiusForZoom(double zoom) {
    if (zoom >= 13) return 10;
    if (zoom >= 11) return 25;
    if (zoom >= 9) return 50;
    if (zoom >= 7) return 100;
    return 200;
  }

  @override
  void initState() {
    super.initState();
    FirebaseHelper.directoryRevision.addListener(_directoryChanged);
    _initializeMap();
    _loadRecommendationProfile();
  }

  @override
  void dispose() {
    FirebaseHelper.directoryRevision.removeListener(_directoryChanged);
    _recommendationProfile?.removeListener(_recommendationsChanged);
    _mapController?.dispose();
    _sheetController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _directoryChanged() {
    if (mounted && _loadedZips.isNotEmpty) {
      _loadForZips(_loadedZips, label: _activeZip);
    }
  }

  Future<void> _loadRecommendationProfile() async {
    try {
      final profile = await RecommendationProfile.forUser(
        Constants.firebaseHelper.userId,
      );
      if (!mounted) return;
      _recommendationProfile = profile;
      profile.addListener(_recommendationsChanged);
      setState(() {});
    } catch (_) {
      // Location-based suggestions remain usable if local preferences fail.
    }
  }

  void _recommendationsChanged() {
    if (mounted) setState(() {});
  }

  void _editInterests() {
    final profile = _recommendationProfile;
    if (profile == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: ArtDecoTheme.surface,
      builder: (_) => BusinessInterestsSheet(profile: profile),
    );
  }

  List<Widget> _recommendationContents() {
    final profile = _recommendationProfile;
    final ranked = rankBusinesses(
      _loadedBusinesses,
      interests: profile?.interests ?? [],
      recentSearches: profile?.recentSearches ?? [],
      viewed: profile?.viewed ?? [],
      latitude: _loadedCenter?.latitude,
      longitude: _loadedCenter?.longitude,
    );
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'You might like',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ArtDecoTheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: profile == null ? null : _editInterests,
            style: TextButton.styleFrom(
              foregroundColor: ArtDecoTheme.backgroundStart,
            ),
            child: const Text('Interests'),
          ),
        ],
      ),
      Text(
        ranked.isEmpty
            ? 'Discover veteran-owned businesses for you.'
            : 'Suggestions around ${_activeZip ?? 'this map area'}',
        style: const TextStyle(
          color: ArtDecoTheme.onSurfaceMuted,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 12),
      if (_isInitializing || _isLoadingBusinesses)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_businessLoadFailed)
        TextButton(
          onPressed: _retryBusinessLoad,
          child: const Text('Retry loading suggestions'),
        )
      else if (_needsZip)
        OutlinedButton.icon(
          onPressed: _openFilterSheet,
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('Choose a ZIP code'),
        )
      else if (ranked.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No businesses loaded in this area. Try another ZIP code.',
          ),
        ),
      for (final recommendation in ranked)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
          title: Text(
            recommendation.business['name']?.toString() ?? 'Business',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${recommendation.reason}\n${_formatLocation(recommendation.business)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final business = recommendation.business;
            final newMarkers = _getBusinessMarkers([business]);
            final ids = newMarkers.map((marker) => marker.markerId).toSet();
            setState(
              () => _businessMarkers = {
                ..._businessMarkers.where(
                  (marker) => !ids.contains(marker.markerId),
                ),
                ...newMarkers,
              },
            );
            if (newMarkers.isNotEmpty) _selectSearchResult(business);
            _openBusinessInfoSheet(business);
          },
        ),
    ];
  }

  void _expandResultsSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          _sheetExpandedSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _collapseResultsSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _sheetPeekSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectSearchResult(Map<String, dynamic> business) {
    _recommendationProfile?.recordView(business);
    final lat = _toDouble(business['lat']);
    final lng = _toDouble(business['lng']);

    if (lat == null || lng == null) {
      Constants.showPopup(
        context,
        'Location Unavailable',
        'This business does not have a valid location yet.',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
    _collapseResultsSheet();
  }

  /// Dismisses the results sheet and its pins, returning the map to whatever
  /// the ZIP lookup had loaded.
  void _clearSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchResults = [];
      _searchMarkers = {};
    });
  }

  Future<void> _recenterToUser() async {
    final target = _userMarker?.position;
    if (target == null) return;
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
    // Recentring is also how someone asks for "what's near me again", so
    // refresh the ZIPs around them rather than leaving whatever was loaded.
    await _loadForLocation(target);
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isInitializing = true;
      _businessLoadFailed = false;
    });
    try {
      _zipService = await ZipService.instance().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _businessLoadFailed = true;
      });
      return;
    }

    LatLng? userCoords;
    try {
      if (Constants.locationManager.serviceEnabled &&
          Constants.locationManager.locationPermission) {
        final position = await Constants.locationManager.location().timeout(
          const Duration(seconds: 8),
        );
        userCoords = LatLng(position.latitude, position.longitude);
      }
    } catch (_) {
      // GPS is optional; manual ZIP lookup and the map remain available.
    }

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _userMarker = userCoords != null ? _createUserMarker(userCoords) : null;
    });

    // A manual ZIP selection takes priority over a delayed GPS result.
    if (userCoords != null && _loadedCenter == null && _retryZips.isEmpty) {
      await _loadForLocation(userCoords);
      if (!mounted) return;
      if (_loadedCenter == userCoords) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userCoords, 13),
        );
      }
    }
  }

  Future<void> _retryBusinessLoad() async {
    if (_zipService == null) {
      await _initializeMap();
    } else {
      await _loadForZips(_retryZips, label: _retryZipLabel);
    }
  }

  /// Loads businesses in the ZIPs surrounding [location].
  ///
  /// The device fix is turned into nearby ZIPs on-device against the bundled
  /// Census table, so this costs no geocoding call.
  Future<void> _loadForLocation(LatLng location) async {
    final service = _zipService;
    if (service == null) return;

    final zips = service.zipsNear(
      location.latitude,
      location.longitude,
      limit: _zipQueryLimit,
    );
    final nearest = service.nearestZip(location.latitude, location.longitude);
    if (nearest != null) _zipController.text = nearest;

    _loadedCenter = location;
    _loadedRadiusMiles = _defaultRadiusMiles;

    await _loadForZips(zips, label: nearest);
  }

  /// Loads businesses for a ZIP the user typed, plus its neighbours.
  Future<void> _loadForZip(String rawZip) async {
    final service = _zipService;
    if (service == null) return;

    final zip = ZipService.normalize(rawZip);
    if (zip.isEmpty) {
      Constants.showPopup(
        context,
        'Invalid ZIP Code',
        'Enter a 5-digit US ZIP code.',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final center = service.centroidOf(zip);
    final zips = service.zipsAroundZip(zip, limit: _zipQueryLimit);

    if (center != null) {
      _loadedCenter = LatLng(center.$1, center.$2);
      _loadedRadiusMiles = _defaultRadiusMiles;
    }

    await _loadForZips(zips, label: zip);

    // A ZIP absent from the bundled table can still have directory results.
    // Use their location so the loaded pins are actually brought into view.
    final resolvedCenter = service.centroidOf(zip);
    if (mounted &&
        !_businessLoadFailed &&
        resolvedCenter != null &&
        _retryZipLabel == zip) {
      _loadedCenter = LatLng(resolvedCenter.$1, resolvedCenter.$2);
      _loadedRadiusMiles = _defaultRadiusMiles;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_loadedCenter!, 13),
      );
    }
  }

  /// Reloads when the camera settles at a different zoom band, or after the
  /// map has been panned far enough that the loaded ZIPs no longer cover what
  /// is on screen.
  Future<void> _handleCameraIdle() async {
    final service = _zipService;
    final position = _lastCameraPosition;
    if (service == null ||
        position == null ||
        _isInitializing ||
        _isLoadingBusinesses ||
        _needsZip ||
        _businessLoadFailed) {
      return;
    }

    final radius = _radiusForZoom(position.zoom);
    final center = position.target;

    final movedMiles = _loadedCenter == null
        ? double.infinity
        : ZipService.milesBetween(
            _loadedCenter!.latitude,
            _loadedCenter!.longitude,
            center.latitude,
            center.longitude,
          );

    // Ignore small nudges so a pan does not fire a query per frame of drift.
    if (radius == _loadedRadiusMiles && movedMiles < radius * 0.5) return;

    await _loadAround(center, radius);
  }

  Future<void> _loadAround(LatLng center, double radiusMiles) async {
    final service = _zipService;
    if (service == null) return;

    final zips = service.zipsWithin(
      center.latitude,
      center.longitude,
      milesRadius: radiusMiles,
      limit: _zipQueryLimit,
    );
    if (zips.isEmpty) return;

    _loadedCenter = center;
    _loadedRadiusMiles = radiusMiles;

    await _loadForZips(
      zips,
      label: service.nearestZip(center.latitude, center.longitude),
    );
  }

  Future<void> _loadForZips(List<String> zips, {String? label}) async {
    if (zips.isEmpty || !mounted) return;

    final requestId = ++_loadRequestId;
    _retryZips = List.of(zips);
    _retryZipLabel = label;
    setState(() {
      _isLoadingBusinesses = true;
      _businessLoadFailed = false;
    });

    try {
      final businesses = await Constants.firebaseHelper.getBusinessesByZips(
        zips,
      );
      if (!mounted || requestId != _loadRequestId) return;
      for (final business in businesses) {
        final zip = business['postalCode'];
        final lat = business['lat'];
        final lng = business['lng'];
        if (zip is String && lat is num && lng is num) {
          _zipService?.rememberBusinessLocation(
            zip,
            lat.toDouble(),
            lng.toDouble(),
          );
        }
      }
      setState(() {
        _businessMarkers = _getBusinessMarkers(businesses);
        _loadedBusinesses = businesses;
        _loadedZips = List.of(zips);
        _loadedZipCount = zips.length;
        _loadedBusinessCount = businesses.length;
        _activeZip = label;
        _needsZip = false;
        _isLoadingBusinesses = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoadingBusinesses = false;
        _businessLoadFailed = true;
      });
    }
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      if (_userMarker != null) _userMarker!.position,
      ..._businessMarkers.map((marker) => marker.position),
    ];
    if (points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 12),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Marker _createUserMarker(LatLng coords) {
    return Marker(
      markerId: const MarkerId('user-location'),
      position: coords,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You are here'),
    );
  }

  /// Metres between co-located pins. Small enough that a ZIP's businesses
  /// still read as one neighbourhood, large enough to tap them apart.
  static const double _spiderfySpacingMetres = 18;

  Set<Marker> _getBusinessMarkers(List<Map<String, dynamic>?> businesses) {
    // Listings without a street address are geocoded to their ZIP's centroid,
    // so every business in a ZIP lands on the identical coordinate -- 42 of
    // them in 32901. Drawn as-is they stack into one tappable pin and the
    // rest are unreachable, so fan co-located pins out around their shared
    // point. Only the display position moves; the stored data is untouched.
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final business in businesses) {
      if (business == null) continue;

      final lat = business['lat'];
      final lng = business['lng'];
      if (lat is! num || lng is! num) continue;

      final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
      (groups[key] ??= []).add(business);
    }

    final Set<Marker> businessMarkers = {};
    for (final group in groups.values) {
      for (var index = 0; index < group.length; index++) {
        final business = group[index];
        final coords = LatLng(
          (business['lat'] as num).toDouble(),
          (business['lng'] as num).toDouble(),
        );

        businessMarkers.add(
          _createBusinessMarker(
            group.length == 1 ? coords : _spiderfy(coords, index),
            business,
          ),
        );
      }
    }

    return businessMarkers;
  }

  /// Places the [index]-th pin of a co-located group on a sunflower spiral
  /// around [center] -- an even scatter that stays tight as the group grows,
  /// rather than a ring that overlaps once there are more than a handful.
  LatLng _spiderfy(LatLng center, int index) {
    if (index == 0) return center;

    // Golden angle, so successive points never line up into spokes.
    const double goldenAngle = 2.399963229728653;
    final angle = index * goldenAngle;
    final radius = _spiderfySpacingMetres * math.sqrt(index);

    final offsetNorth = radius * math.cos(angle);
    final offsetEast = radius * math.sin(angle);

    const double metresPerDegreeLat = 111320;
    final latOffset = offsetNorth / metresPerDegreeLat;
    final lngOffset =
        offsetEast /
        (metresPerDegreeLat * math.cos(center.latitude * math.pi / 180));

    return LatLng(center.latitude + latOffset, center.longitude + lngOffset);
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatLocation(Map<String, dynamic> business) {
    final address = BusinessDirections.addressLabel(business);
    if (address.isNotEmpty) return address;
    final lat = _toDouble(business['lat']);
    final lng = _toDouble(business['lng']);
    if (lat == null || lng == null) return 'Not available';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  void _openBusinessInfoSheet(Map<String, dynamic> business) {
    _recommendationProfile?.recordView(business);
    final name = business['name']?.toString() ?? 'Unknown Business';
    final started = business['startDate']?.toString() ?? 'Not available';
    final description =
        business['description']?.toString().trim().isNotEmpty == true
        ? business['description'].toString().trim()
        : 'No description provided.';
    final location = _formatLocation(business);
    final distance = _toDouble(business['distanceMiles']);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final outerTheme = Theme.of(context);
        return Theme(
          data: outerTheme.copyWith(
            textTheme: ArtDecoTheme.onSurfaceTextTheme(outerTheme.textTheme),
            iconTheme: outerTheme.iconTheme.copyWith(
              color: ArtDecoTheme.onSurface,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Builder(
                  builder: (context) {
                    final textTheme = Theme.of(context).textTheme;
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.toUpperCase(), style: textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text('STARTED: $started'),
                          const SizedBox(height: 6),
                          Text('LOCATION: $location'),
                          const SizedBox(height: 6),
                          Text(
                            'DESCRIPTION: $description',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (distance != null) ...[
                            const SizedBox(height: 6),
                            Text('DISTANCE: ${distance.toStringAsFixed(1)} MI'),
                          ],
                          const SizedBox(height: 14),
                          BusinessPhotoGallery(
                            urls: (business['photoUrls'] as List? ?? [])
                                .whereType<String>()
                                .toList(),
                          ),
                          BusinessDirectionsButton(business: business),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Marker _createBusinessMarker(LatLng coords, Map<String, dynamic> info) {
    final id =
        info['id']?.toString() ?? '${coords.latitude},${coords.longitude}';

    return Marker(
      markerId: MarkerId(id),
      position: coords,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: (info['name'] ?? 'Unknown Business').toString(),
      ),
      onTap: () => _openBusinessInfoSheet(info),
    );
  }

  Widget _mapDisplay() {
    // Search hits win over ZIP-loaded pins for the same business: both carry
    // the same MarkerId, and google_maps_flutter rejects duplicate ids.
    final seenIds = _searchMarkers.map((marker) => marker.markerId).toSet();
    final markers = <Marker>{
      if (_userMarker != null) _userMarker!,
      ..._searchMarkers,
      ..._businessMarkers.where((marker) => !seenIds.contains(marker.markerId)),
    };

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _defaultCenter,
        zoom: 4,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToMarkers();
      },
      onCameraMove: (position) => _lastCameraPosition = position,
      onCameraIdle: _handleCameraIdle,
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _floatingSearchBar() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
            iconTheme: theme.iconTheme.copyWith(color: ArtDecoTheme.onSurface),
            inputDecorationTheme: ArtDecoTheme.onSurfaceInputDecorationTheme(),
            // The search field sits on a white pill, so the cursor and
            // selection need the dark on-surface treatment too.
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: ArtDecoTheme.onSurface,
              selectionColor: ArtDecoTheme.onSurface.withAlpha(60),
              selectionHandleColor: ArtDecoTheme.onSurface,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ArtDecoTheme.pillRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: BusinessSearch(
                dense: true,
                onQuerySubmitted: (query) =>
                    _recommendationProfile?.recordSearch(query),
                onSearch: _limitSearchToArea && _loadedZips.isNotEmpty
                    ? (query) => Constants.firebaseHelper
                          .searchBusinessesInZips(query, _loadedZips)
                    : null,
                onResultsChanged: (results) {
                  setState(() {
                    _searchResults = results;
                    _searchMarkers = _getBusinessMarkers(results);
                  });
                  if (results.isNotEmpty) _expandResultsSheet();
                },
                onAiSearchTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.businessAiSearch,
                  arguments: _loadedCenter == null
                      ? null
                      : AiSearchArea(
                          ll.LatLng(
                            _loadedCenter!.latitude,
                            _loadedCenter!.longitude,
                          ),
                          _activeZip == null
                              ? 'this map area'
                              : 'the map area near $_activeZip',
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens the ZIP / area controls, which live in a sheet rather than on the
  /// map so the map itself stays visible.
  Widget _filterButton() {
    final active = _activeZip != null || _limitSearchToArea;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _circleButton(
          icon: Icons.tune_rounded,
          onPressed: _openFilterSheet,
          tooltip: 'Filter by ZIP code',
        ),
        if (active)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: ArtDecoTheme.backgroundStart,
                shape: BoxShape.circle,
                border: Border.all(color: ArtDecoTheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openFilterSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final outerTheme = Theme.of(sheetContext);

        return Theme(
          // The app's default button and cursor colors are tuned for the dark
          // gradient background, so on this white sheet they come out white
          // on white. Apply the same on-surface overrides RoundedCard uses.
          data: outerTheme.copyWith(
            textTheme: ArtDecoTheme.onSurfaceTextTheme(outerTheme.textTheme),
            iconTheme: outerTheme.iconTheme.copyWith(
              color: ArtDecoTheme.onSurface,
            ),
            inputDecorationTheme: ArtDecoTheme.onSurfaceInputDecorationTheme(),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: ArtDecoTheme.onSurfaceOutlineButtonStyle(),
            ),
            textButtonTheme: TextButtonThemeData(
              style: ArtDecoTheme.onSurfaceTextButtonStyle(),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: ArtDecoTheme.onSurface,
              selectionColor: ArtDecoTheme.onSurface.withAlpha(60),
              selectionHandleColor: ArtDecoTheme.onSurface,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            // Local state so the switch responds immediately; the page is
            // updated through setState in the callbacks below.
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final canLimit = _loadedZips.isNotEmpty;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter businesses',
                        style: GoogleFonts.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ArtDecoTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _zipController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.search,
                        maxLength: 10,
                        autofocus: true,
                        onSubmitted: (value) {
                          Navigator.of(sheetContext).pop();
                          _loadForZip(value);
                        },
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'ZIP code',
                          hintText: 'e.g. 33602',
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _limitSearchToArea && canLimit,
                        onChanged: canLimit
                            ? (value) {
                                setState(() => _limitSearchToArea = value);
                                setSheetState(() {});
                              }
                            : null,
                        activeThumbColor: ArtDecoTheme.backgroundStart,
                        title: Text(
                          'Search this area only',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ArtDecoTheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          canLimit
                              ? 'Keyword searches stay within the '
                                    '${_loadedRadiusMiles.round()} mi around '
                                    '${_activeZip ?? 'this area'}.'
                              : 'Load an area first to use this.',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: ArtDecoTheme.onSurfaceMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_userMarker != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _recenterToUser();
                                },
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  size: 18,
                                ),
                                label: const Text('Near me'),
                              ),
                            ),
                          if (_userMarker != null) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _loadForZip(_zipController.text);
                              },
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Tells the user what the map is currently showing, so an empty area reads
  /// as "nothing here" rather than "the app is broken".
  Widget _zipStatusPill() {
    // A keyword search covers the whole directory, so the ZIP counts describe
    // something the user is no longer looking at -- and "no businesses near
    // 21797" reads as a contradiction next to a list of results. The results
    // sheet already reports its own count, so stay out of the way.
    if (_searchResults.isNotEmpty && !_businessLoadFailed) {
      return const SizedBox.shrink();
    }

    final String message;
    if (_businessLoadFailed) {
      message = 'Businesses could not load.';
    } else if (_isLoadingBusinesses) {
      message = 'Loading businesses…';
    } else if (_isInitializing) {
      message = 'Loading nearby area…';
    } else if (_needsZip) {
      message = 'Enter a ZIP code to find businesses';
    } else if (_activeZip == null) {
      return const SizedBox.shrink();
    } else if (_loadedBusinessCount == 0) {
      message =
          'No businesses within '
          '${_loadedRadiusMiles.round()} mi of $_activeZip';
    } else {
      message =
          '$_loadedBusinessCount within '
          '${_loadedRadiusMiles.round()} mi of $_activeZip '
          '($_loadedZipCount ZIP${_loadedZipCount == 1 ? '' : 's'})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ArtDecoTheme.surface,
        borderRadius: BorderRadius.circular(ArtDecoTheme.pillRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isLoadingBusinesses || _isInitializing) ...[
            const CupertinoActivityIndicator(),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.quicksand(
                color: ArtDecoTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_businessLoadFailed)
            TextButton(
              onPressed: _retryBusinessLoad,
              style: ArtDecoTheme.onSurfaceTextButtonStyle(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Round white map control, matching the recenter/zoom treatment.
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: ArtDecoTheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: ArtDecoTheme.backgroundStart, size: 20),
      ),
    );
  }

  Widget _recenterButton() {
    return _circleButton(
      icon: Icons.my_location_rounded,
      onPressed: _recenterToUser,
      tooltip: 'Recenter on my location',
    );
  }

  // Google's built-in zoom controls only render on Android, so draw our own
  // to get the same affordance on both platforms and in the app's styling.
  Future<void> _zoomBy(double delta) async {
    await _mapController?.animateCamera(CameraUpdate.zoomBy(delta));
  }

  Widget _zoomButtons() {
    return Column(
      children: [
        _circleButton(
          icon: Icons.add_rounded,
          onPressed: () => _zoomBy(1),
          tooltip: 'Zoom in',
        ),
        const SizedBox(height: 8),
        _circleButton(
          icon: Icons.remove_rounded,
          onPressed: () => _zoomBy(-1),
          tooltip: 'Zoom out',
        ),
      ],
    );
  }

  Widget _mapOverlayControls() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: double.infinity, child: _floatingSearchBar()),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _zipStatusPill()),
                const SizedBox(width: 10),
                _filterButton(),
              ],
            ),
            if (_userMarker != null) ...[
              const SizedBox(height: 10),
              _recenterButton(),
            ],
            const SizedBox(height: 10),
            _zoomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _destinationRow(Map<String, dynamic> business) {
    return InkWell(
      onTap: () => _selectSearchResult(business),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArtDecoTheme.backgroundStart.withAlpha(28),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: ArtDecoTheme.backgroundStart,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (business['name'] ?? 'Unknown Business')
                        .toString()
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Builder(
                    builder: (context) => Text(
                      _formatLocation(business),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: ArtDecoTheme.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _sheetPeekSize,
      minChildSize: _sheetPeekSize,
      maxChildSize: _sheetMaxSize,
      builder: (context, scrollController) {
        final outerTheme = Theme.of(context);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Color(0x2213183B), blurRadius: 24),
            ],
          ),
          child: Theme(
            data: outerTheme.copyWith(
              textTheme: ArtDecoTheme.onSurfaceTextTheme(outerTheme.textTheme),
              iconTheme: outerTheme.iconTheme.copyWith(
                color: ArtDecoTheme.onSurface,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Builder(
                builder: (context) {
                  final textTheme = Theme.of(context).textTheme;
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ArtDecoTheme.onSurfaceMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (_searchResults.isEmpty) ..._recommendationContents(),
                      if (_searchResults.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_searchResults.length} BUSINESS${_searchResults.length == 1 ? '' : 'ES'} FOUND',
                                style: textTheme.labelMedium,
                              ),
                            ),
                            // The sheet cannot be dragged below its peek
                            // height, so without this there is no way to get
                            // it off the map once a search has run.
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _clearSearch,
                              tooltip: 'Clear search',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: ArtDecoTheme.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ..._searchResults
                          .map((business) => _destinationRow(business))
                          .expand(
                            (row) => [
                              row,
                              const Divider(height: 1, thickness: 0.6),
                            ],
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            Positioned.fill(child: _mapDisplay()),
            Positioned(top: 0, left: 0, right: 0, child: _mapOverlayControls()),
            _resultsSheet(),
          ],
        ),
      ),
    );
  }
}
