import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool locationEnabled = true;
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF007AFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // General Section
            _buildSectionHeader('GENERAL'),
            _buildSection([
              _buildListTile(
                title: 'Language',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'English',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                onTap: () => _showLanguageDialog(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Notification Settings',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToNotifications(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Location',
                trailing: Switch(
                  value: locationEnabled,
                  activeColor: const Color(0xFF007AFF),
                  onChanged: (value) {
                    setState(() {
                      locationEnabled = value;
                    });
                  },
                ),
                onTap: null,
              ),
              _buildListTile(
                title: 'Dark Mode',
                trailing: Switch(
                  value: isDarkMode,
                  activeColor: const Color(0xFF007AFF),
                  onChanged: (value) {
                    setState(() {
                      isDarkMode = value;
                    });
                  },
                ),
                onTap: null,
              ),
            ]),

            const SizedBox(height: 30),

            // Account & Security Section
            _buildSectionHeader('ACCOUNT & SECURITY'),
            _buildSection([
              _buildListTile(
                title: 'Email and Mobile Number',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToAccountInfo(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Security Settings',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToSecurity(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Delete Account',
                titleColor: Colors.red,
                leading: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _showDeleteAccountDialog(),
              ),
            ]),

            const SizedBox(height: 30),

            // Other Section
            _buildSectionHeader('OTHER'),
            _buildSection([
              _buildListTile(
                title: 'Smart Bus Mobility',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToAbout(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Privacy Policy',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToPrivacyPolicy(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Terms and Conditions',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _navigateToTerms(),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Smart Bus Mobility',
                leading: const Icon(
                  Icons.star_outline,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _rateApp(),
              ),
            ]),

            const SizedBox(height: 50),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(right: 20, bottom: 20),
              child: Text(
                'v4.87.2',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: isDarkMode ? Colors.grey[900] : const Color(0xFFF5F5F5),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required String title,
    Widget? leading,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: titleColor ?? (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 20,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
      indent: 20,
      endIndent: 0,
    );
  }

  // Navigation and Action Methods
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Vietnamese'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('French'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToNotifications() {
    showDialog(
      context: context,
      builder: (context) {
        bool pushNotifications = true;
        bool emailNotifications = false;
        bool smsNotifications = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Notification Preferences'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  value: pushNotifications,
                  onChanged: (val) => setState(() => pushNotifications = val),
                ),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  value: emailNotifications,
                  onChanged: (val) => setState(() => emailNotifications = val),
                ),
                SwitchListTile(
                  title: const Text('SMS Notifications'),
                  value: smsNotifications,
                  onChanged: (val) => setState(() => smsNotifications = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('Save'),
                onPressed: () {
                  // Save preferences logic here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification preferences saved.'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToAccountInfo() {
    final emailController = TextEditingController(text: 'user@email.com');
    final phoneController = TextEditingController(text: '+256 700 000000');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Account Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              // Save logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account info updated.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToSecurity() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              // Save logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Add backend account deletion logic here
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted.')),
                );
                // Optionally, navigate to login or splash screen
              }
            },
          ),
        ],
      ),
    );
  }

  void _navigateToAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Smart Bus Mobility'),
        content: const Text(
          'Smart Bus Mobility is a platform to make your bus journeys easier, safer, and smarter. Version 4.87.2.',
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'We value your privacy. Your data is protected and will not be shared without your consent.',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Smart Bus Mobility, you agree to our terms and conditions.',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _rateApp() async {
    const appStoreUrl =
        'https://play.google.com/store/apps/details?id=com.example.smart_bus_mobility_platform1';
    if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
      await launchUrl(
        Uri.parse(appStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the app store.')),
      );
    }
  }
}
