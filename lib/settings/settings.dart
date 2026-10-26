import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vetconnect/business/widgets/business_photo_gallery.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/main.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _userLatController = TextEditingController();
  final TextEditingController _userLngController = TextEditingController();

  final TextEditingController _businessZipController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessDescriptionController =
      TextEditingController();
  final TextEditingController _businessLatController = TextEditingController();
  final TextEditingController _businessLngController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isSavingBusiness = false;
  bool _isDeletingBusiness = false;
  bool _isDeletingAccount = false;
  bool _isLoggingOut = false;

  bool get _hasBusiness => Constants.businessHandler.name != null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _userNameController.text = Constants.firebaseHelper.userName ?? '';

    final profileData = await Constants.firebaseHelper.getUserProfile();
    if (profileData != null) {
      final profileLat = profileData['lat'];
      final profileLng = profileData['lng'];
      if (profileLat is num && profileLng is num) {
        _userLatController.text = profileLat.toString();
        _userLngController.text = profileLng.toString();
      }
    }

    _businessZipController.text = Constants.businessHandler.postalCode;
    _businessNameController.text = Constants.businessHandler.name ?? '';
    _businessDescriptionController.text =
        Constants.businessHandler.description ?? '';
    final businessLocation = Constants.businessHandler.location;
    if (businessLocation != null) {
      _businessLatController.text = businessLocation.latitude.toString();
      _businessLngController.text = businessLocation.longitude.toString();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    final cleanedName = _userNameController.text.trim();
    final latitude = double.tryParse(_userLatController.text.trim());
    final longitude = double.tryParse(_userLngController.text.trim());

    if (cleanedName.isEmpty) {
      Constants.showPopup(
        context,
        'Invalid Name',
        'Please enter a valid user name.',
      );
      return;
    }

    final hasLocation =
        _userLatController.text.trim().isNotEmpty ||
        _userLngController.text.trim().isNotEmpty;
    if (hasLocation &&
        (latitude == null ||
            longitude == null ||
            !latitude.isFinite ||
            !longitude.isFinite ||
            latitude.abs() > 90 ||
            longitude.abs() > 180)) {
      Constants.showPopup(
        context,
        'Invalid Location',
        'Please enter valid latitude and longitude values.',
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    final nameUpdated = await Constants.firebaseHelper.setUserName(cleanedName);
    final locationUpdated =
        !hasLocation ||
        await Constants.firebaseHelper.setUserLocation(
          LatLng(latitude!, longitude!),
        );

    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    Constants.showPopup(
      context,
      nameUpdated && locationUpdated
          ? 'Profile Updated'
          : 'Unable to Update Profile',
      nameUpdated && locationUpdated
          ? 'Your profile settings were saved successfully.'
          : 'Please try again in a moment.',
    );
  }

  Future<void> _saveBusiness() async {
    final cleanedName = _businessNameController.text.trim();
    final cleanedDescription = _businessDescriptionController.text.trim();
    final latitude = double.tryParse(_businessLatController.text.trim());
    final longitude = double.tryParse(_businessLngController.text.trim());

    if (!RegExp(r'^[0-9]{5}$').hasMatch(_businessZipController.text.trim())) {
      Constants.showPopup(
        context,
        'Invalid ZIP code',
        'Enter a 5-digit business ZIP code.',
      );
      return;
    }
    if (cleanedName.isEmpty) {
      Constants.showPopup(
        context,
        'Invalid Business Name',
        'Please enter a valid business name.',
      );
      return;
    }

    if (latitude == null || longitude == null) {
      Constants.showPopup(
        context,
        'Invalid Business Location',
        'Please enter valid latitude and longitude values.',
      );
      return;
    }

    setState(() => _isSavingBusiness = true);
    final success = await Constants.businessHandler.updateBusiness(
      cleanedName,
      LatLng(latitude, longitude),
      cleanedDescription,
      postalCode: _businessZipController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSavingBusiness = false);

    Constants.showPopup(
      context,
      success ? 'Business Updated' : 'Unable to Update Business',
      success
          ? 'Your business settings were saved successfully.'
          : 'Please try again in a moment.',
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title.toUpperCase()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText.toUpperCase()),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _clearBusinessFields() {
    _businessZipController.clear();
    _businessNameController.clear();
    _businessDescriptionController.clear();
    _businessLatController.clear();
    _businessLngController.clear();
  }

  Future<void> _deleteBusiness() async {
    if (!_hasBusiness || _isDeletingBusiness) return;

    final confirmed = await _confirmAction(
      title: 'Delete Business',
      message:
          'This will permanently remove your business profile from your account.',
      confirmText: 'Delete',
    );

    if (!confirmed) return;

    setState(() => _isDeletingBusiness = true);
    final success = await Constants.businessHandler.deleteBusiness();

    if (!mounted) return;
    setState(() => _isDeletingBusiness = false);

    if (success) {
      _clearBusinessFields();
      setState(() {});
    }

    Constants.showPopup(
      context,
      success ? 'Business Deleted' : 'Unable to Delete Business',
      success
          ? 'Your business profile has been removed.'
          : 'Please try again in a moment.',
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;

    if (Constants.firebaseHelper.anonymous) {
      Constants.showPopup(
        context,
        'Account Action Unavailable',
        'Anonymous accounts cannot be deleted from this screen.',
      );
      return;
    }

    final confirmed = await _confirmAction(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and cannot be undone.',
      confirmText: 'Delete Account',
    );

    if (!confirmed) return;

    setState(() => _isDeletingAccount = true);
    final success = await Constants.firebaseHelper.deleteAccount();

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }

    Constants.showPopup(
      context,
      'Unable to Delete Account',
      'Please re-authenticate and try again.',
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print("Unable to sign out: $e");
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Widget _settingsInput({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: RoundedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ArtDecoTheme.backgroundStart.withAlpha(28),
                  ),
                  child: Icon(
                    icon,
                    color: ArtDecoTheme.backgroundStart,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: ArtDecoTheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _userLatController.dispose();
    _userLngController.dispose();
    _businessZipController.dispose();
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _businessLatController.dispose();
    _businessLngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArtDecoScaffold(
      appBar: AppBar(title: const Text('Settings')),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  children: [
                    PageIntro(
                      title: 'Your account',
                      subtitle: Constants.firebaseHelper.canManageBusiness
                          ? 'Manage your profile, veteran business, and preferences.'
                          : 'Manage your profile and preferences.',
                    ),
                    _section(
                      icon: Icons.route_outlined,
                      title: Constants.firebaseHelper.pathway?.label ?? 'User',
                      children: [
                        if (!Constants.firebaseHelper.anonymous)
                          OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.choosePathway,
                              arguments: true,
                            ),
                            child: const Text('Change pathway'),
                          )
                        else
                          const Text(
                            'Sign up to save your profile and choose a pathway.',
                          ),
                      ],
                    ),
                    if (!Constants.firebaseHelper.anonymous)
                      _section(
                        icon: Icons.person_rounded,
                        title: 'Profile Settings',
                        children: [
                          _settingsInput(
                            controller: _userNameController,
                            label: 'USER NAME',
                          ),
                          _settingsInput(
                            controller: _userLatController,
                            label: 'LATITUDE (optional)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                          _settingsInput(
                            controller: _userLngController,
                            label: 'LONGITUDE (optional)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSavingProfile ? null : _saveProfile,
                              child: _isSavingProfile
                                  ? const CupertinoActivityIndicator()
                                  : const Text('SAVE PROFILE'),
                            ),
                          ),
                        ],
                      ),
                    if (Constants.firebaseHelper.canManageBusiness)
                      _section(
                        icon: Icons.storefront_rounded,
                        title: 'Business Settings',
                        children: _hasBusiness
                            ? [
                                BusinessPhotoGallery(
                                  urls: Constants.businessHandler.photoUrls,
                                ),
                                _settingsInput(
                                  controller: _businessNameController,
                                  label: 'BUSINESS NAME',
                                ),
                                _settingsInput(
                                  controller: _businessDescriptionController,
                                  label: 'BUSINESS DESCRIPTION',
                                  maxLines: 3,
                                ),
                                _settingsInput(
                                  controller: _businessZipController,
                                  label: 'BUSINESS ZIP CODE',
                                  keyboardType: TextInputType.number,
                                ),
                                _settingsInput(
                                  controller: _businessLatController,
                                  label: 'BUSINESS LATITUDE',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                                _settingsInput(
                                  controller: _businessLngController,
                                  label: 'BUSINESS LONGITUDE',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSavingBusiness
                                        ? null
                                        : _saveBusiness,
                                    child: _isSavingBusiness
                                        ? const CupertinoActivityIndicator()
                                        : const Text('SAVE BUSINESS'),
                                  ),
                                ),
                              ]
                            : [
                                Builder(
                                  builder: (context) => Text(
                                    'No business profile found yet. Create one from the Create tab.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                      ),
                    _section(
                      icon: Icons.lock_outline_rounded,
                      title: 'Account',
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoggingOut ? null : _logout,
                            child: _isLoggingOut
                                ? const CupertinoActivityIndicator()
                                : const Text('LOG OUT'),
                          ),
                        ),
                      ],
                    ),
                    _section(
                      icon: Icons.warning_amber_rounded,
                      title: 'Danger Zone',
                      children: [
                        if (Constants.firebaseHelper.canManageBusiness &&
                            _hasBusiness)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isDeletingBusiness
                                  ? null
                                  : _deleteBusiness,
                              child: _isDeletingBusiness
                                  ? const CupertinoActivityIndicator()
                                  : const Text('DELETE BUSINESS'),
                            ),
                          ),
                        if (Constants.firebaseHelper.canManageBusiness &&
                            _hasBusiness)
                          const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isDeletingAccount
                                ? null
                                : _deleteAccount,
                            child: _isDeletingAccount
                                ? const CupertinoActivityIndicator()
                                : const Text('DELETE ACCOUNT'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
