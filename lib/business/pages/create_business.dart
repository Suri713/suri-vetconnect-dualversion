import 'dart:io';
import 'package:flutter/services.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/services/media_picker_service.dart';
import 'package:vetconnect/services/business_photo_upload.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class CreateBusiness extends StatefulWidget {
  final Future<List<File>> Function(int remaining)? pickImages;

  const CreateBusiness({super.key, this.pickImages});

  @override
  State<CreateBusiness> createState() => _CreateBusinessState();
}

class _CreateBusinessState extends State<CreateBusiness> {
  final TextEditingController _dodIdController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  gmaps.GoogleMapController? _mapController;
  DateTime _selectedDate = DateTime.now();
  LatLng? _selectedLocation;
  gmaps.Marker? _locationMarker;
  bool _isLoading = false;
  bool _isGeocoding = false;
  bool _isPickingImages = false;
  final List<File> _photos = [];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDisplayDate(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<bool> _confirmReplaceBusiness() async {
    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REPLACE EXISTING BUSINESS?'),
        content: const Text(
          'You already have a business profile. Your existing profile will be replaced after the new details and photos are saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REPLACE'),
          ),
        ],
      ),
    );

    return shouldReplace ?? false;
  }

  Future<void> createNewBusiness() async {
    if (_isLoading ||
        _isPickingImages ||
        !Constants.firebaseHelper.canManageBusiness)
      return;
    if (!isValidDodId(_dodIdController.text)) {
      Constants.showPopup(
        context,
        'Department of Defense ID required',
        'Enter your 10 digit Department of Defense ID number.',
      );
      return;
    }
    if (!RegExp(r'^[0-9]{5}$').hasMatch(_zipController.text.trim())) {
      Constants.showPopup(
        context,
        'Business ZIP code required',
        'Enter a 5-digit ZIP code so people can find your business on the map.',
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      Constants.showPopup(
        context,
        "Missing Name",
        "Please enter a name for your business.",
      );
      return;
    }

    if (_selectedLocation == null) {
      Constants.showPopup(
        context,
        "Missing Location",
        "Please tap the map to select your business location.",
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    final existingBusiness = await Constants.firebaseHelper.getBusiness(
      Constants.firebaseHelper.userId,
    );

    if (!mounted) return;

    final replaceExisting =
        existingBusiness != null && existingBusiness.isNotEmpty;
    if (replaceExisting) {
      final shouldReplace = await _confirmReplaceBusiness();
      if (!mounted) return;
      if (!shouldReplace) {
        setState(() => _isLoading = false);
        return;
      }
    }

    final String startDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final bool success = await Constants.businessHandler.createBusiness(
      _nameController.text.trim(),
      startDate,
      _selectedLocation,
      _descriptionController.text.trim(),
      photos: List.of(_photos),
      replaceExisting: replaceExisting,
      dodId: _dodIdController.text.trim(),
      postalCode: _zipController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    _dodIdController.clear();

    Constants.showPopup(
      context,
      success ? "Business Created" : "Unable to Create Business",
      success
          ? "Your veteran business profile has been saved and added to the map directory."
          : "We were unable to create your business at this time. Please try again.",
    );
  }

  Future<void> _pickImages() async {
    if (_isLoading || _isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final remaining = BusinessPhotoUpload.maxPhotos - _photos.length;
      final selected = widget.pickImages == null
          ? await MediaPickerService.pickBusinessImages(remaining: remaining)
          : await widget.pickImages!(remaining);
      final valid = <File>[];
      for (final file in selected) {
        if (await file.length() <= BusinessPhotoUpload.maxBytes) {
          valid.add(file);
        }
      }
      if (!mounted) return;
      setState(() => _photos.addAll(valid));
      if (valid.length != selected.length) {
        Constants.showPopup(
          context,
          'Image too large',
          'Please choose images smaller than 10 MB.',
        );
      }
    } catch (_) {
      if (mounted) {
        Constants.showPopup(
          context,
          'Unable to select images',
          'Please check photo access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  Widget _imagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business images', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'Add up to 6 photos of your business, products, or services.',
        ),
        const SizedBox(height: 12),
        if (_photos.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _photos[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          semanticLabel: 'Selected business image ${i + 1}',
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 100,
                            height: 100,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filled(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() => _photos.removeAt(i)),
                          tooltip: 'Remove image ${i + 1}',
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed:
              _isLoading ||
                  _isPickingImages ||
                  _photos.length >= BusinessPhotoUpload.maxPhotos
              ? null
              : _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _isPickingImages
                ? 'Opening photos…'
                : 'Add images (${_photos.length}/6)',
          ),
        ),
      ],
    );
  }

  void _setSelectedLocation(gmaps.LatLng point) {
    setState(() {
      _selectedLocation = LatLng(point.latitude, point.longitude);
      _locationMarker = gmaps.Marker(
        markerId: const gmaps.MarkerId('selected-location'),
        position: point,
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueAzure,
        ),
      );
    });
  }

  void _onMapTap(gmaps.LatLng point) {
    _setSelectedLocation(point);
    _reverseGeocode(point);
  }

  String _formatPlacemark(Placemark placemark) {
    final parts = [
      placemark.street,
      placemark.locality,
      placemark.administrativeArea,
      placemark.postalCode,
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  Future<void> _reverseGeocode(gmaps.LatLng point) async {
    setState(() => _isGeocoding = true);

    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || placemarks.isEmpty) return;

      final address = _formatPlacemark(placemarks.first);
      if (address.isNotEmpty) {
        _addressController.text = address;
      }
    } catch (e) {
      print("Reverse geocoding failed: $e");
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isGeocoding = true);

    try {
      final locations = await Geocoding().locationFromAddress(address);
      if (!mounted) return;

      if (locations.isEmpty) {
        Constants.showPopup(
          context,
          "Address Not Found",
          "We couldn't find that address. Try refining it or tap the map instead.",
        );
        return;
      }

      final result = locations.first;
      final point = gmaps.LatLng(result.latitude, result.longitude);
      _setSelectedLocation(point);
      await _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(point, 15),
      );
    } catch (e) {
      print("Geocoding failed: $e");
      if (!mounted) return;
      Constants.showPopup(
        context,
        "Address Lookup Failed",
        "We couldn't look up that address right now. Please try again or tap the map.",
      );
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textButtonTheme: TextButtonThemeData(
              style: ArtDecoTheme.onSurfaceTextButtonStyle(),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  gmaps.LatLng _initialMapCenter() {
    if (Constants.locationManager.serviceEnabled &&
        Constants.locationManager.locationPermission) {
      final loc = Constants.businessHandler.location;
      if (loc != null) return gmaps.LatLng(loc.latitude, loc.longitude);
    }
    return const gmaps.LatLng(39.8283, -98.5795);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _dodIdController.dispose();
    _zipController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.quicksand(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: ArtDecoTheme.onSurfaceMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Constants.firebaseHelper.canManageBusiness) {
      return const ArtDecoScaffold(
        child: Center(
          child: Text(
            'Choose the Veteran pathway in Settings to create a business.',
          ),
        ),
      );
    }
    return ArtDecoScaffold(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const PageIntro(
                    title: 'Put your veteran business on the map',
                    subtitle:
                        'Share your services and help your community find you.',
                  ),
                  RoundedCard(
                    child: Builder(
                      builder: (context) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            key: const Key('dod-id'),
                            controller: _dodIdController,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Department of Defense ID number',
                              hintText:
                                  'Enter your 10 digit Department of Defense ID number',
                              helperText:
                                  '10 digits required. Your number is not saved.',
                              helperMaxLines: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Business name',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'About your business',
                              hintText: 'Tell the community what you do',
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showDatePicker,
                              icon: const Icon(Icons.calendar_month_rounded),
                              label: Text(
                                'Started ${_formatDisplayDate(_selectedDate)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _fieldLabel(
                            'SET YOUR LOCATION — ENTER AN ADDRESS OR TAP THE MAP',
                          ),
                          TextField(
                            controller: _addressController,
                            onSubmitted: (_) => _geocodeAddress(),
                            decoration: InputDecoration(
                              hintText: '123 Main St, City, State',
                              suffixIcon: _isGeocoding
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CupertinoActivityIndicator(),
                                    )
                                  : IconButton(
                                      onPressed: _geocodeAddress,
                                      icon: const Icon(Icons.search),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('business-zip'),
                            controller: _zipController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 5,
                            decoration: const InputDecoration(
                              labelText: 'Business ZIP code',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 260,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                ArtDecoTheme.pillRadius,
                              ),
                              child: gmaps.GoogleMap(
                                initialCameraPosition: gmaps.CameraPosition(
                                  target: _initialMapCenter(),
                                  zoom: 4,
                                ),
                                onMapCreated: (controller) =>
                                    _mapController = controller,
                                onTap: _onMapTap,
                                zoomControlsEnabled: false,
                                markers: _locationMarker != null
                                    ? {_locationMarker!}
                                    : {},
                              ),
                            ),
                          ),
                          if (_selectedLocation != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 22),
                          _imagePicker(),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? const Center(
                                    child: CupertinoActivityIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: createNewBusiness,
                                    child: const Text('Create business'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
