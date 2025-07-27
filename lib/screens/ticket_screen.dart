import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, active, completed, cancelled

  @override
  void initState() {
    super.initState();
    _loadUserBookings();
  }

  Future<void> _loadUserBookings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get all bookings for the current user
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> bookings = [];

      for (var doc in snapshot.docs) {
        final bookingData = doc.data();

        // Get bus details for each booking
        final busDoc = await FirebaseFirestore.instance
            .collection('buses')
            .doc(bookingData['busId'])
            .get();

        if (busDoc.exists) {
          final busData = busDoc.data() as Map<String, dynamic>;
          bookings.add({
            'bookingId': doc.id,
            'busData': busData,
            ...bookingData,
          });
        }
      }

      // Sort bookings by creation time in descending order
      bookings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order
      });

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    switch (_selectedFilter) {
      case 'active':
        return _bookings
            .where(
              (booking) =>
                  booking['status'] == 'confirmed' &&
                  booking['departureDate'] != null &&
                  (booking['departureDate'] as Timestamp).toDate().isAfter(
                        DateTime.now(),
                      ),
            )
            .toList();
      case 'completed':
        return _bookings
            .where(
              (booking) =>
                  booking['status'] == 'completed' ||
                  (booking['departureDate'] != null &&
                      (booking['departureDate'] as Timestamp).toDate().isBefore(
                            DateTime.now(),
                          )),
            )
            .toList();
      case 'cancelled':
        return _bookings
            .where((booking) => booking['status'] == 'cancelled')
            .toList();
      default:
        return _bookings;
    }
  }

  Color _getStatusColor(String status, DateTime? departureDate) {
    if (status == 'cancelled') return Colors.red;
    if (status == 'completed') return Colors.grey;
    if (departureDate != null && departureDate.isBefore(DateTime.now())) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _getStatusText(String status, DateTime? departureDate) {
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'completed') return 'Completed';
    if (departureDate != null && departureDate.isBefore(DateTime.now())) {
      return 'Active';
    }
    return 'Active';
  }

  String formatDate(DateTime date) {
    final daySuffix = _getDayOfMonthSuffix(date.day);
    final formatted = DateFormat('EEEE d').format(date) +
        daySuffix +
        DateFormat(' MMMM, yyyy').format(date);
    return formatted;
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserBookings,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('userId',
                      isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading tickets: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                final tickets = snapshot.data!.docs;
                // Sort tickets by creation time in memory
                tickets.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Descending order
                });

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final doc = tickets[index];
                    final data = doc.data();
                    if (data == null) return const SizedBox.shrink();
                    final ticket = data as Map<String, dynamic>;
                    // Add the document ID to the ticket data
                    ticket['id'] = doc.id;
                    return _buildTicketCard(ticket);
                  },
                );
              },
            ),
    );
  }

  Widget _buildFilterButton(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green[700]! : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.green[700] : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tickets found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'You haven\'t booked any tickets yet'
                : 'No $_selectedFilter tickets found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    // Get the correct fields from the booking data
    final totalFare = ticket['totalFare'] ?? 0.0;
    final isPaid = ticket['isPaid'] ?? false;
    final status = ticket['status'] ?? 'pending';
    final departureDate = ticket['departureDate'] is Timestamp
        ? (ticket['departureDate'] as Timestamp).toDate()
        : DateTime.now();
    final destination =
        ticket['destination'] ?? ticket['route'] ?? 'Unknown Destination';
    final pickupAddress = ticket['pickupAddress'] ?? 'Unknown Pickup';
    final bookingId = ticket['id'] ?? 'Unknown ID';
    final busId = ticket['busId'];

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('buses').doc(busId).get(),
      builder: (context, busSnapshot) {
        String busPlate = 'Unknown Bus';
        if (busSnapshot.hasData && busSnapshot.data!.exists) {
          final busData = busSnapshot.data!.data() as Map<String, dynamic>?;
          busPlate = busData?['numberPlate'] ?? 'Unknown Bus';
        }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ticket #${bookingId.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status, departureDate),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(status, departureDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.directions_bus,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bus: $busPlate',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To: $destination',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(departureDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount: UGX ${totalFare.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.cancel,
                      color: isPaid ? Colors.green[700] : Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment: ${isPaid ? 'Yes' : 'No'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
        );
      },
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadUserBookings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewTicketDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Booking ID: ${booking['bookingId']}'),
              const SizedBox(height: 8),
              Text('Status: ${booking['status']}'),
              const SizedBox(height: 8),
              Text(
                'Total Fare: UGX ${(booking['totalFare'] ?? 0.0).toStringAsFixed(0)}',
              ),
              if (booking['pickupAddress'] != null) ...[
                const SizedBox(height: 8),
                Text('Pickup: ${booking['pickupAddress']}'),
              ],
              if (booking['selectedSeats'] != null) ...[
                const SizedBox(height: 8),
                Text('Seats: ${booking['selectedSeats'].join(', ')}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}



