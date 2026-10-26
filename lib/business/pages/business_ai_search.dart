import 'dart:math' as math;
import 'package:vetconnect/services/nearby_business_search.dart';
import 'package:vetconnect/services/zip_service.dart';
import 'package:vetconnect/services/business_recommendations.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/business/widgets/business_photo_gallery.dart';
import 'package:vetconnect/business/widgets/business_directions_button.dart';
import 'package:vetconnect/services/business_directions.dart';
import 'package:vetconnect/services/openai_handler.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class BusinessAiSearch extends StatefulWidget {
  final AiSearchArea? initialArea;
  const BusinessAiSearch({super.key, this.initialArea});

  @override
  State<BusinessAiSearch> createState() => _BusinessAiSearchState();
}

class _BusinessAiSearchState extends State<BusinessAiSearch> {
  static const LatLng _defaultCenter = LatLng(39.8283, -98.5795);
  static const double _sheetPeekSize = 0.12;
  static const double _sheetExpandedSize = 0.65;
  static const double _sheetMaxSize = 0.7;

  final TextEditingController _zipController = TextEditingController();
  String? _areaLabel;
  final TextEditingController _inputController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _aiResults = [];
  Set<Marker> _resultMarkers = {};
  bool _isProcessing = false;
  String? _errorMessage;
  String? _generatedQuery;

  @override
  void dispose() {
    _mapController?.dispose();
    _inputController.dispose();
    _zipController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> getAIRecommendedBusinesses(
    String input,
  ) async {
    final service = await ZipService.instance();
    AiSearchArea? area;
    final zip = _zipController.text.trim();
    if (zip.isNotEmpty) {
      if (!RegExp(r'^[0-9]{5}$').hasMatch(zip)) {
        throw const FormatException('Enter a valid 5-digit ZIP code.');
      }
      var center = service.centroidOf(zip);
      if (center == null) {
        final local = await Constants.firebaseHelper.getBusinessesByZips([zip]);
        for (final business in local) {
          if (business['lat'] is num && business['lng'] is num) {
            service.rememberBusinessLocation(
              zip,
              (business['lat'] as num).toDouble(),
              (business['lng'] as num).toDouble(),
            );
          }
        }
        center = service.centroidOf(zip);
      }
      if (center == null)
        throw const FormatException(
          'That ZIP code could not be located. Try a nearby ZIP code.',
        );
      area = AiSearchArea(ll.LatLng(center.$1, center.$2), 'ZIP $zip');
    } else if (widget.initialArea != null) {
      area = widget.initialArea;
    } else {
      try {
        final access = await Constants.locationManager.refreshLocationAccess(
          requestPermissionIfNeeded: false,
        );
        if (access.name == 'available') {
          final position = await Constants.locationManager.location().timeout(
            const Duration(seconds: 8),
          );
          area = AiSearchArea(
            ll.LatLng(position.latitude, position.longitude),
            'your location',
          );
        }
      } catch (_) {
        // A ZIP is required below if GPS is unavailable. Never search globally.
      }
    }
    if (area == null)
      throw const FormatException(
        'Enter a ZIP code or enable location to find businesses within 20 miles.',
      );
    if (!mounted) return [];
    setState(() => _areaLabel = area!.label);
    final searchQuery = await OpenaiHandler.getSearchRecommendation(input);
    if (!mounted || searchQuery.isEmpty) return [];
    setState(() => _generatedQuery = searchQuery);
    _rememberInteraction(query: searchQuery);
    return Constants.firebaseHelper.searchBusinessesWithinRadius(
      searchQuery,
      area.center,
    );
  }

  Future<void> _rememberInteraction({
    String? query,
    Map<String, dynamic>? business,
  }) async {
    try {
      final profile = await RecommendationProfile.forUser(
        Constants.firebaseHelper.userId,
      );
      if (query != null) await profile.recordSearch(query);
      if (business != null) await profile.recordView(business);
    } catch (_) {
      // A local history issue should not prevent AI search or business details.
    }
  }

  Future<void> _getAIRecommendations() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _generatedQuery = null;
      _aiResults = [];
      _resultMarkers = {};
    });

    try {
      final results = await getAIRecommendedBusinesses(input);

      if (!mounted) return;

      setState(() {
        _aiResults = results;
        _resultMarkers = _buildMarkers(results);
        _isProcessing = false;
      });

      if (results.isEmpty) {
        setState(() {
          _errorMessage =
              'No matching businesses within 20 miles of ${_areaLabel ?? 'this area'}. Try another search or ZIP code.';
        });
      } else {
        _expandResultsSheet();
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToMarkers());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e is FormatException
            ? e.message
            : 'Failed to get AI recommendations. Please check your connection and try again.';
      });
      print('AI search error: $e');
    }
  }

  Set<Marker> _buildMarkers(List<Map<String, dynamic>> businesses) {
    final Set<Marker> markers = {};
    for (final business in businesses) {
      final lat = business['lat'];
      final lng = business['lng'];
      if (lat is! num || lng is! num) continue;

      final id = business['id']?.toString() ?? '$lat,$lng';
      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(lat.toDouble(), lng.toDouble()),
          infoWindow: InfoWindow(
            title: (business['name'] ?? 'Unknown Business').toString(),
          ),
          onTap: () => _openBusinessInfoSheet(business),
        ),
      );
    }
    return markers;
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null || _resultMarkers.isEmpty) return;

    final points = _resultMarkers.map((marker) => marker.position).toList();
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
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
    _rememberInteraction(business: business);
    final lat = business['lat'];
    final lng = business['lng'];
    if (lat is! num || lng is! num) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat.toDouble(), lng.toDouble()), 16),
    );
    _collapseResultsSheet();
  }

  Widget _mapDisplay() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _defaultCenter,
        zoom: 4,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToMarkers();
      },
      markers: _resultMarkers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _requestCard() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textTheme: ArtDecoTheme.onSurfaceTextTheme(theme.textTheme),
            iconTheme: theme.iconTheme.copyWith(color: ArtDecoTheme.onSurface),
            inputDecorationTheme: ArtDecoTheme.onSurfaceInputDecorationTheme(),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ArtDecoTheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ArtDecoTheme.backgroundStart.withAlpha(28),
                        ),
                        child: const Icon(
                          CupertinoIcons.sparkles,
                          color: ArtDecoTheme.backgroundStart,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Describe what you need',
                          style: GoogleFonts.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ArtDecoTheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Only businesses within 20 miles of ${_areaLabel ?? widget.initialArea?.label ?? 'your location or ZIP code'}. Distances use listed locations; some pins are approximate.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _zipController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: const InputDecoration(
                      labelText:
                          'Search near ZIP code (optional with location)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inputController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'I need a vet-owned coffee shop with outdoor seating...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _getAIRecommendations,
                      child: _isProcessing
                          ? const CupertinoActivityIndicator()
                          : const Text('Find businesses'),
                    ),
                  ),
                  if (_generatedQuery != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Searched for "$_generatedQuery"',
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        color: ArtDecoTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArtDecoTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: AppColors.destructive,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.quicksand(
                fontSize: 12.5,
                color: ArtDecoTheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchOverlay() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_requestCard(), if (_errorMessage != null) _errorCard()],
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
                    (business['name'] ?? 'Unknown Business').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Builder(
                    builder: (context) => Text(
                      _locationLabel(business),
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
                      Text(
                        '${_aiResults.length} BUSINESS${_aiResults.length == 1 ? '' : 'ES'} FOUND',
                        style: textTheme.labelMedium,
                      ),
                      ..._aiResults
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

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _openBusinessInfoSheet(Map<String, dynamic> business) {
    _rememberInteraction(business: business);
    final name = business['name']?.toString() ?? 'Unknown Business';
    final started = business['startDate']?.toString() ?? 'Not available';
    final description =
        business['description']?.toString().trim().isNotEmpty == true
        ? business['description'].toString().trim()
        : 'No description provided.';
    final location = _locationLabel(business);
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
                          Text(name, style: textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text('Started: $started'),
                          const SizedBox(height: 6),
                          Text('Location: $location'),
                          const SizedBox(height: 6),
                          Text(
                            'Description: $description',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (distance != null) ...[
                            const SizedBox(height: 6),
                            Text('Distance: ${distance.toStringAsFixed(1)} mi'),
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

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      appBar: AppBar(title: const Text('Find your next connection')),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            Positioned.fill(child: _mapDisplay()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: SingleChildScrollView(child: _searchOverlay()),
              ),
            ),
            if (_aiResults.isNotEmpty) _resultsSheet(),
          ],
        ),
      ),
    );
  }
}

String _locationLabel(Map<String, dynamic> business) {
  final address = BusinessDirections.addressLabel(business);
  if (address.isNotEmpty) return address;
  final lat = business['lat'];
  final lng = business['lng'];

  if (lat is num && lng is num) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  return 'Location not available';
}
