import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'personal_data_screen.dart';
import 'nav_bar_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_screen.dart';
import 'payment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedIndex = 4; // Profile tab index
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isEditMode = false;
  bool isUploadingImage = false;
  final _formKey = GlobalKey<FormState>();
  String? _editName;
  String? _editEmail;
  String? _editPhone;
  String? _profileImageUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _logout() async {
    // Show confirmation dialog
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Navigate to login screen and clear all previous routes
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Show immediate loading state and fetch data
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Add timeout to prevent hanging
        final timeout = Future.delayed(const Duration(milliseconds: 2000));
        // First, get the role from the users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        String role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'user';
        final collection = (role == 'driver') ? 'drivers' : 'users';
        final docFuture = FirebaseFirestore.instance
            .collection(collection)
            .doc(user.uid)
            .get();
        // Race between timeout and Firestore call
        final doc = await Future.any([docFuture, timeout.then((_) => null)]);
        if (mounted) {
          setState(() {
            userData = doc?.data();
            isLoading = false;
            _editName = userData?['username'] ?? '';
            _editEmail = userData?['email'] ?? '';
            _editPhone = userData?['contact'] ?? '';
            _profileImageUrl = userData?['profileImageUrl'] ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Image picking and uploading methods
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
        
        // Automatically upload the image
        await _uploadProfileImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_selectedImageFile == null) return;
    setState(() {
      isUploadingImage = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');
      // Get role to determine collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'user';
      final collection = (role == 'driver') ? 'drivers' : 'users';

      // Create a unique filename
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      // Upload the image
      UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the new image URL
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        _profileImageUrl = downloadUrl;
        _selectedImageFile = null;
        isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Choose Profile Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get role to determine collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'user';
      final collection = (role == 'driver') ? 'drivers' : 'users';
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).update({
        'username': _editName,
        'email': _editEmail,
        'contact': _editPhone,
      });
      await _fetchUserData();
      setState(() {
        isEditMode = false;
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF004d00),
                const Color(0xFF006400),
                const Color(0xFF808080).withOpacity(0.3),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header skeleton
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 80,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content skeleton
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile header skeleton
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar skeleton
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Name skeleton
                              Container(
                                width: 150,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Email skeleton
                              Container(
                                width: 200,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Options skeleton
                        for (int i = 0; i < 5; i++) ...[
                          Container(
                            width: double.infinity,
                            height: 70,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final name = userData?['username'] ?? 'No Name';
    final email = userData?['email'] ?? 'No Email';
    final phone = userData?['contact'] ?? 'No Phone';
    final imageUrl = userData?['profileImageUrl'] ?? '';
    final role = (userData?['role']?.toString().toLowerCase() ?? 'user');
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final headerFont = isMobile ? 20.0 : 28.0;
    final nameFont = isMobile ? 24.0 : 32.0;
    final contentPad = isMobile ? 20.0 : 40.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF004d00),
              const Color(0xFF006400),
              const Color(0xFF808080).withOpacity(0.3),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .get();
                            final role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'user';
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NavBarScreen(userRole: role, initialTab: 0),
                              ),
                              (route) => false,
                            );
                          } else {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                      ),
                    ),
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: headerFont,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (!isEditMode)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () {
                                setState(() => isEditMode = true);
                              },
                            ),
                          ),
                        if (isEditMode)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() => isEditMode = false);
                              },
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () => Navigator.pushNamed(context, '/settings'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: contentPad),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 20 : 36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isMobile ? 18 : 25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Profile Picture
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: _showImagePickerDialog,
                                  child: CircleAvatar(
                                    radius: isMobile ? 48 : 60,
                                    backgroundColor: Colors.green[700],
                                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                        ? NetworkImage(_profileImageUrl!)
                                        : null,
                                    child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                                        ? Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                            style: TextStyle(
                                              fontSize: isMobile ? 32 : 40,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                // Upload indicator
                                if (isUploadingImage)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green[700],
                                        shape: BoxShape.circle,
                                      ),
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Camera icon overlay
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[700],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Editable fields
                            if (isEditMode)
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      initialValue: _editName,
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                                      onSaved: (v) => _editName = v,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      initialValue: _editEmail,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? 'Enter your email' : null,
                                      onSaved: (v) => _editEmail = v,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      initialValue: _editPhone,
                                      decoration: const InputDecoration(
                                        labelText: 'Phone',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? 'Enter your phone' : null,
                                      onSaved: (v) => _editPhone = v,
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _saveProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // User Name
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: nameFont,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // User Email
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  color: Colors.grey[600],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // User Phone
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Profile Options
                      _buildProfileOption(
                        icon: Icons.person,
                        title: 'Personal Information',
                        subtitle: 'Update your personal details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalData(
                                initialName: name,
                                initialEmail: email,
                                initialPhone: phone,
                              ),
                            ),
                          );
                        },
                      ),

                      if (role == 'user' || role == 'passenger') ...[
                        const SizedBox(height: 15),
                        _buildProfileOption(
                          icon: Icons.confirmation_number,
                          title: 'My Tickets',
                          subtitle: 'View your ticket history',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TicketScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        _buildProfileOption(
                          icon: Icons.location_on,
                          title: 'My Routes',
                          subtitle: 'View your favorite routes',
                          onTap: () {
                            _onItemTapped(2); // Go to Live Location
                          },
                        ),
                        const SizedBox(height: 15),
                      ],

                      if (role == 'user' || role == 'passenger') ...[
                        const SizedBox(height: 15),
                        _buildProfileOption(
                          icon: Icons.payment,
                          title: 'Payment Methods',
                          subtitle: 'Manage your payment options',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                      ],

                      _buildProfileOption(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'Manage your notification preferences',
                        onTap: () {
                          _onItemTapped(3); // Go to Settings
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {
                          // TODO: Navigate to help screen
                        },
                      ),

                      const SizedBox(height: 15),

                      // Logout option
                      _buildProfileOption(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out of your account',
                        onTap: _logout,
                      ),

                      const SizedBox(height: 30),

                      const SizedBox(height: 100), // Extra space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.green[700], size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.green[700], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : Colors.white,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.green[800] : Colors.black,
          size: 24,
        ),
      ),
    );
  }

  void _onItemTapped(int index) async {
    if (index != 4) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'user';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NavBarScreen(userRole: role, initialTab: index),
          ),
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
    // If profile tab (index 4), stay on current screen
  }
}








