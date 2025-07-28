import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UpdateBusApp());
}

class UpdateBusApp extends StatelessWidget {
  const UpdateBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Update Bus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const UpdateBusScreen(),
    );
  }
}

class UpdateBusScreen extends StatefulWidget {
  const UpdateBusScreen({super.key});

  @override
  State<UpdateBusScreen> createState() => _UpdateBusScreenState();
}

class _UpdateBusScreenState extends State<UpdateBusScreen> {
  bool _isLoading = false;
  String _status = '';
  final _driverEmailController =
      TextEditingController(text: 'tagooledavid3@gmail.com');

  @override
  void dispose() {
    _driverEmailController.dispose();
    super.dispose();
  }

  Future<void> _updateBus() async {
    setState(() {
      _isLoading = true;
      _status = 'Searching for bus...';
    });

    try {
      final driverEmail = _driverEmailController.text.trim();

      // Find the bus by driver email
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driverId', isEqualTo: driverEmail)
          .limit(1)
          .get();

      if (busSnapshot.docs.isEmpty) {
        setState(() {
          _status = 'No bus found for driver: $driverEmail';
          _isLoading = false;
        });
        return;
      }

      final busDoc = busSnapshot.docs.first;
      final busId = busDoc.id;
      final busData = busDoc.data();

      setState(() {
        _status = 'Found bus with ID: $busId\nUpdating...';
      });

      // Update the bus with isAvailable field
      await FirebaseFirestore.instance.collection('buses').doc(busId).update({
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status =
            'Bus updated successfully!\n\nBus ID: $busId\nDriver: $driverEmail\nBus data: $busData';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error updating bus: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Bus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _driverEmailController,
              decoration: const InputDecoration(
                labelText: 'Driver Email',
                hintText: 'Enter driver email',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateBus,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Update Bus'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                width: double.infinity,
                child: Text(_status),
              ),
          ],
        ),
      ),
    );
  }
}











