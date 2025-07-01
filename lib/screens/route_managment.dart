import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PickupPoint {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double lat;
  final double lng;

  PickupPoint({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.lat,
    required this.lng,
  });

  PickupPoint copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? lat,
    double? lng,
  }) {
    return PickupPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class RouteManagementProvider with ChangeNotifier {
  List<PickupPoint> pickupPoints = [];
  PickupPoint? selectedPoint;
  bool isOptimizing = false;

  void addPickupPoint(PickupPoint point) {
    pickupPoints.add(point);
    notifyListeners();
  }

  void addPickupPoints(List<PickupPoint> points) {
    pickupPoints.addAll(points);
    notifyListeners();
  }

  void updatePickupPoint(String id, PickupPoint updated) {
    final idx = pickupPoints.indexWhere((p) => p.id == id);
    if (idx != -1) {
      pickupPoints[idx] = updated;
      notifyListeners();
    }
  }

  void removePickupPoint(String id) {
    pickupPoints.removeWhere((p) => p.id == id);
    if (selectedPoint?.id == id) selectedPoint = null;
    notifyListeners();
  }

  void selectPoint(PickupPoint? point) {
    selectedPoint = point;
    notifyListeners();
  }

  Future<void> optimizeRoute() async {
    isOptimizing = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    isOptimizing = false;
    notifyListeners();
  }

  void clear() {
    pickupPoints.clear();
    selectedPoint = null;
    isOptimizing = false;
    notifyListeners();
  }
}

class RouteManagementScreen extends StatelessWidget {
  const RouteManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RouteManagementProvider(),
      child: const _RouteManagementBody(),
    );
  }
}

class _RouteManagementBody extends StatefulWidget {
  const _RouteManagementBody();

  @override
  State<_RouteManagementBody> createState() => _RouteManagementBodyState();
}

class _RouteManagementBodyState extends State<_RouteManagementBody> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(icon: Icon(Icons.map), text: "Manual Entry"),
    Tab(icon: Icon(Icons.upload_file), text: "File Upload"),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RouteManagementProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar (optional, can be expanded)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey[300]!),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Route Management",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Create optimized pickup routes for drivers",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: _tabs,
                  labelColor: Colors.blue[800],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[800],
                  indicatorWeight: 3,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      PickupFormWidget(),
                      FileUploadWidget(),
                    ],
                  ),
                ),
                if (provider.pickupPoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: PickupPointsListWidget(),
                  ),
                if (provider.pickupPoints.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: RouteOptimizerWidget(),
                  ),
              ],
            ),
          ),
          // Map Panel
          Expanded(
            child: Stack(
              children: [
                MapViewWidget(),
                if (provider.pickupPoints.isEmpty)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.85),
                      child: Center(
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(Icons.pin_drop, color: Colors.blue[700], size: 36),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  "No Pickup Points Yet",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Add pickup points manually or upload a file to get started with route optimization.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Manual Entry Form ---
class PickupFormWidget extends StatefulWidget {
  @override
  State<PickupFormWidget> createState() => _PickupFormWidgetState();
}

class _PickupFormWidgetState extends State<PickupFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    double? lat = double.tryParse(_lat.text);
    double? lng = double.tryParse(_lng.text);

    // Mock geocoding if not provided
    lat ??= 37.7749 + (Random().nextDouble() - 0.5) * 0.1;
    lng ??= -122.4194 + (Random().nextDouble() - 0.5) * 0.1;

    final point = PickupPoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text,
      phone: _phone.text,
      address: _address.text,
      lat: lat,
      lng: lng,
    );

    Provider.of<RouteManagementProvider>(context, listen: false).addPickupPoint(point);

    _formKey.currentState!.reset();
    _name.clear();
    _phone.clear();
    _address.clear();
    _lat.clear();
    _lng.clear();

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pickup point added!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: "Name *"),
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: "Phone *"),
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: "Address *"),
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    decoration: const InputDecoration(labelText: "Latitude"),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    decoration: const InputDecoration(labelText: "Longitude"),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt),
                label: Text(_isSubmitting ? "Adding..." : "Add Pickup Point"),
                onPressed: _isSubmitting ? null : () => _submit(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- File Upload Widget ---
class FileUploadWidget extends StatefulWidget {
  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  bool _isProcessing = false;

  Future<void> _pickFile(BuildContext context) async {
    setState(() => _isProcessing = true);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      try {
        List<PickupPoint> points = [];
        if (file.extension == 'json') {
          final data = json.decode(utf8.decode(file.bytes!));
          for (var item in data) {
            points.add(PickupPoint(
              id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(9999).toString(),
              name: item['name'] ?? 'Unknown',
              phone: item['phone'] ?? '',
              address: item['address'] ?? '',
              lat: (item['lat'] ?? item['latitude'] ?? 0).toDouble(),
              lng: (item['lng'] ?? item['longitude'] ?? 0).toDouble(),
            ));
          }
        } else if (file.extension == 'csv') {
          final lines = utf8.decode(file.bytes!).split('\n').where((l) => l.trim().isNotEmpty).toList();
          final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
          for (var line in lines.skip(1)) {
            final values = line.split(',');
            final map = <String, String>{};
            for (int i = 0; i < headers.length; i++) {
              map[headers[i]] = values.length > i ? values[i].trim() : '';
            }
            points.add(PickupPoint(
              id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(9999).toString(),
              name: map['name'] ?? 'Unknown',
              phone: map['phone'] ?? '',
              address: map['address'] ?? '',
              lat: double.tryParse(map['lat'] ?? '') ?? 37.7749 + (Random().nextDouble() - 0.5) * 0.1,
              lng: double.tryParse(map['lng'] ?? '') ?? -122.4194 + (Random().nextDouble() - 0.5) * 0.1,
            ));
          }
        }
        Provider.of<RouteManagementProvider>(context, listen: false).addPickupPoints(points);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${points.length} pickup points!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process file: $e')),
        );
      }
    }
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file, size: 48, color: Colors.blue[700]),
              const SizedBox(height: 12),
              Text(
                _isProcessing ? "Processing..." : "Upload CSV or JSON file",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "CSV: name, phone, address, lat, lng\nJSON: Array of objects with same fields",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text("Choose File"),
                onPressed: _isProcessing ? null : () => _pickFile(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Pickup Points List Widget ---
class PickupPointsListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RouteManagementProvider>(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.pin_drop, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text("Pickup Points (${provider.pickupPoints.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...provider.pickupPoints.map((point) {
              final isSelected = provider.selectedPoint?.id == point.id;
              return ListTile(
                selected: isSelected,
                selectedTileColor: Colors.blue[50],
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey[400],
                  child: Text(
                    (provider.pickupPoints.indexOf(point) + 1).toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(point.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("${point.phone}\n${point.address}", maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        final updated = await showDialog<PickupPoint>(
                          context: context,
                          builder: (ctx) => _EditPickupPointDialog(point: point),
                        );
                        if (updated != null) {
                          Provider.of<RouteManagementProvider>(context, listen: false)
                              .updatePickupPoint(point.id, updated);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        Provider.of<RouteManagementProvider>(context, listen: false)
                            .removePickupPoint(point.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pickup point removed')),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () => provider.selectPoint(point),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EditPickupPointDialog extends StatefulWidget {
  final PickupPoint point;
  const _EditPickupPointDialog({required this.point});

  @override
  State<_EditPickupPointDialog> createState() => _EditPickupPointDialogState();
}

class _EditPickupPointDialogState extends State<_EditPickupPointDialog> {
  late TextEditingController _name, _phone, _address;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.point.name);
    _phone = TextEditingController(text: widget.point.phone);
    _address = TextEditingController(text: widget.point.address);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Pickup Point"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: "Phone")),
          TextField(controller: _address, decoration: const InputDecoration(labelText: "Address")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.point.copyWith(
                name: _name.text,
                phone: _phone.text,
                address: _address.text,
              ),
            );
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

// --- Route Optimizer Widget ---
class RouteOptimizerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RouteManagementProvider>(context);
    final points = provider.pickupPoints;
    final isOptimizing = provider.isOptimizing;
    final estimatedTime = (points.length * 1.5).ceil();
    final estimatedDistance = (points.length * 2.3).ceil();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text("Route Optimization", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.pin_drop, color: Colors.blue),
                    Text("${points.length} Points", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.timer, color: Colors.green),
                    Text("~${estimatedTime}min", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.straighten, color: Colors.orange),
                    Text("${estimatedDistance} km", style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isOptimizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.route),
                label: Text(isOptimizing ? "Optimizing..." : "Optimize Route"),
                onPressed: isOptimizing
                    ? null
                    : () async {
                        await provider.optimizeRoute();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Route optimized!')),
                        );
                      },
              ),
            ),
            if (points.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Add at least 2 pickup points to enable optimization",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Map View Widget (Mock) ---
class MapViewWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RouteManagementProvider>(context);
    final points = provider.pickupPoints;
    final selected = provider.selectedPoint;

    return Container(
      color: Colors.blue[50],
      child: Stack(
        children: [
          // Mock grid background
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
          // Markers
          ...points.asMap().entries.map((entry) {
            final idx = entry.key;
            final point = entry.value;
            final left = 0.2 + (idx * 0.15) % 0.6;
            final top = 0.3 + (idx * 0.2) % 0.4;
            return Positioned(
              left: left * MediaQuery.of(context).size.width,
              top: top * MediaQuery.of(context).size.height,
              child: GestureDetector(
                onTap: () => provider.selectPoint(point),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: selected?.id == point.id ? 48 : 40,
                      height: selected?.id == point.id ? 48 : 40,
                      decoration: BoxDecoration(
                        color: selected?.id == point.id ? Colors.red : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected?.id == point.id ? Colors.red[100]! : Colors.blue[100]!,
                          width: selected?.id == point.id ? 4 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${idx + 1}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        point.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Map Legend
          Positioned(
            top: 24,
            left: 24,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Map Legend", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text("Pickup Points", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text("Selected Point", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Map Info
          Positioned(
            bottom: 24,
            right: 24,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Points: ${points.length}", style: const TextStyle(fontSize: 13)),
                    if (selected != null)
                      Text("Selected: ${selected.name}", style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += size.width / 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += size.height / 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}