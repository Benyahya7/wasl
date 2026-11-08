import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/photo_service.dart';
import 'package:latlong2/latlong.dart';
import 'map_pin_picker.dart';
import '../theme.dart';

/// First-time sign-in: pick a role. The profile is created as pending;
/// the admin approves it before the account can post orders or see jobs.
class OnboardingScreen extends StatefulWidget {
  final AuthService auth;
  final User user;
  final void Function(AppUser profile) onProfileCreated;

  const OnboardingScreen({
    super.key,
    required this.auth,
    required this.user,
    required this.onProfileCreated,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zoneController = TextEditingController();
  String _role = 'store';
  String _market = 'boston';
  String _storeType = 'restaurant';
  String _vehicle = 'car';
  String? _storeId;
  LatLng? _storePin;
  String? _error;
  bool _busy = false;
  final _photos = PhotoService();
  String? _proofUrl;
  String? _proofPublicId;
  bool _uploadingProof = false;

  /// Proof document: the store/driver photographs an ID or licence.
  /// Uploaded at once (same free Cloudinary storage as the delivery
  /// photos) — the admin checks it on the approval card before
  /// approving the account.
  Future<void> _pickProof() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ID or licence photo'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Take a photo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Choose from gallery'),
          ),
        ],
      ),
    );
    if (source == null) return;
    setState(() {
      _uploadingProof = true;
      _error = null;
    });
    final picked = await _photos.pickImage(source: source);
    String? localPath;
    picked.fold((p) => localPath = p, (m) => _error = m);
    if (localPath == null) {
      setState(() => _uploadingProof = false);
      return;
    }
    final uploaded =
        await _photos.uploadFile(localPath!, resourceType: 'image');
    if (!mounted) return;
    uploaded.fold((u) {
      setState(() {
        _proofUrl = u?.url;
        _proofPublicId = u?.publicId;
        _uploadingProof = false;
        if (u == null) {
          _error =
              'Photo storage is not set up yet — ask the admin before signing up.';
        }
      });
    }, (m) => setState(() {
          _error = m;
          _uploadingProof = false;
        }));
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName ?? '';
    _businessController.text = widget.user.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _pickStorePin() async {
    final address = _addressController.text.trim();
    final picked = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPinPicker(
            address: address.isEmpty
                ? _businessController.text.trim()
                : address,
            initialPin: _storePin),
      ),
    );
    if (picked is LatLng) {
      setState(() => _storePin = picked);
    } else if (picked == false) {
      setState(() => _storePin = null);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    // Role-specific info — Google sign-in is only the login; the admin
    // approves the account from the full info below.
    final extra = <String, dynamic>{'phone': phone};
    // Proof document: stores and drivers must upload an ID or licence
    // photo — the admin checks it before approving. Customers do not.
    if (_role != 'customer') {
      if (_proofUrl == null) {
        setState(() => _error =
            'Please upload a photo of your ID or licence — the admin checks it before approving your account.');
        return;
      }
      extra['proofImageUrl'] = _proofUrl;
      if (_proofPublicId != null) extra['proofPublicId'] = _proofPublicId;
    }
    if (_role == 'store') {
      final business = _businessController.text.trim();
      final address = _addressController.text.trim();
      if (business.isEmpty ||
          phone.isEmpty ||
          address.isEmpty ||
          _storePin == null) {
        setState(() => _error =
            'Please enter the business name, your phone and the address, and pin your store on the map.');
        return;
      }
      extra.addAll({
        'businessName': business,
        'address': address,
        'market': _market,
        'storeType': _storeType,
        'storeLat': _storePin!.latitude,
        'storeLng': _storePin!.longitude,
      });
    } else if (_role == 'own-driver') {
      if (phone.isEmpty || _storeId == null) {
        setState(() => _error =
            'Please enter your phone and pick the store you drive for.');
        return;
      }
      extra.addAll({'vehicle': _vehicle, 'storeId': _storeId});
    } else if (_role == 'marketplace-driver') {
      if (phone.isEmpty) {
        setState(() => _error = 'Please enter your phone.');
        return;
      }
      extra.addAll({
        'vehicle': _vehicle,
        'homeZone': _zoneController.text.trim(),
      });
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _role == 'customer'
        ? await widget.auth.createCustomerProfile(
            user: widget.user,
            name: name,
            extra: extra,
          )
        : await widget.auth.createPendingProfile(
            user: widget.user,
            role: _role,
            name: name,
            extra: extra,
          );
    result.fold(
      (profile) => widget.onProfileCreated(profile),
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your Wasl account')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signed in as ${widget.user.email ?? ''}'),
              const SizedBox(height: 8),
              const Text(
                'Google only signs you in — add your information below so the admin can confirm your account.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 16),
              const Text('I am a…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile<String>(
                title: const Text('Store'),
                subtitle:
                    const Text('Restaurant, coffee shop or grocery store'),
                value: 'store',
                groupValue: _role,
                onChanged: (v) => setState(() => _role = v!),
              ),
              RadioListTile<String>(
                title: const Text('Own driver'),
                subtitle: const Text('I drive for one store'),
                value: 'own-driver',
                groupValue: _role,
                onChanged: (v) => setState(() => _role = v!),
              ),
              RadioListTile<String>(
                title: const Text('Marketplace driver'),
                subtitle: const Text('I take deliveries from any store'),
                value: 'marketplace-driver',
                groupValue: _role,
                onChanged: (v) => setState(() => _role = v!),
              ),
              RadioListTile<String>(
                title: const Text('Customer'),
                subtitle: const Text(
                    'I order from stores — no approval needed'),
                value: 'customer',
                groupValue: _role,
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 8),
              if (_role == 'store') ...[
                TextField(
                  controller: _businessController,
                  decoration: const InputDecoration(
                      labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration:
                      const InputDecoration(labelText: 'Store address'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickStorePin,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Pin your store on the map'),
                ),
                if (_storePin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pinned: ${_storePin!.latitude.toStringAsFixed(5)}, ${_storePin!.longitude.toStringAsFixed(5)} — the driver gets directions to this exact spot.',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _market,
                  decoration: const InputDecoration(labelText: 'Market'),
                  items: const [
                    DropdownMenuItem(value: 'boston', child: Text('Boston')),
                    DropdownMenuItem(
                        value: 'morocco', child: Text('Morocco')),
                  ],
                  onChanged: (v) =>
                      setState(() => _market = v ?? 'boston'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _storeType,
                  decoration:
                      const InputDecoration(labelText: 'Store type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'restaurant', child: Text('Restaurant')),
                    DropdownMenuItem(
                        value: 'coffee', child: Text('Coffee shop')),
                    DropdownMenuItem(
                        value: 'grocery', child: Text('Grocery store')),
                  ],
                  onChanged: (v) =>
                      setState(() => _storeType = v ?? 'restaurant'),
                ),
              ],
              if (_role == 'own-driver' ||
                  _role == 'marketplace-driver') ...[
                DropdownButtonFormField<String>(
                  value: _vehicle,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle'),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                    DropdownMenuItem(value: 'bike', child: Text('Bike')),
                    DropdownMenuItem(
                        value: 'scooter', child: Text('Scooter')),
                    DropdownMenuItem(
                        value: 'on foot', child: Text('On foot')),
                  ],
                  onChanged: (v) => setState(() => _vehicle = v ?? 'car'),
                ),
              ],
              if (_role == 'own-driver') ...[
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: DriverService().approvedStoresStream(),
                  builder: (context, snapshot) {
                    final stores = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value: _storeId,
                      decoration: const InputDecoration(
                          labelText: 'The store I drive for'),
                      hint: const Text('Pick a store'),
                      items: stores
                          .map((doc) => DropdownMenuItem<String>(
                                value: (doc.data()['ownerUid'] ?? '')
                                    .toString(),
                                child: Text(
                                    (doc.data()['name'] ?? '').toString()),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _storeId = v),
                    );
                  },
                ),
                if (_storeId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Only approved stores show here — if your store is not listed yet, it has to be approved first.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
              ],
              if (_role == 'marketplace-driver') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _zoneController,
                  decoration: const InputDecoration(
                      labelText: 'Home zone (e.g. East Boston)'),
                ),
              ],
              if (_role != 'customer') ...[
                const SizedBox(height: 16),
                const Text(
                  'ID or licence photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'The admin checks this before approving your account.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (_proofUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _proofUrl!,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Text('Photo could not load.'),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _uploadingProof ? null : _pickProof,
                  icon: const Icon(Icons.badge),
                  label: Text(_proofUrl == null
                      ? 'Upload ID or licence photo'
                      : 'Replace photo'),
                ),
                if (_uploadingProof)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waiting screen for pending accounts.
class PendingApprovalScreen extends StatelessWidget {
  final AppUser profile;
  final AuthService auth;
  final VoidCallback onRefresh;

  const PendingApprovalScreen({
    super.key,
    required this.profile,
    required this.auth,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wasl')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top,
                size: 56, color: WaslTheme.amber),
            const SizedBox(height: 16),
            Text(
              'Hi ${profile.name} — your account is waiting for approval.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'The Wasl admin reviews every store and driver before they can post orders or see jobs. You will be able to use the app as soon as you are approved.',
              textAlign: TextAlign.center,
            ),
            if (profile.verificationStatus == 'rejected') ...[
              const SizedBox(height: 16),
              ErrorBanner(
                message: 'Your account was not approved.'
                    '${profile.verificationReason != null ? ' Reason: ${profile.verificationReason}' : ''}',
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Check again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => auth.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
