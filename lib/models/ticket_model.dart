class TicketModel {
  final String ticketId;
  final String userId;
  final String busId;
  final String routeId;
  final DateTime dateTime;
  final double price;
  final bool isPaid;

  TicketModel(
    {
      required this.ticketId, 
      required this.userId, 
      required this.busId, 
      required this.routeId, 
      required this.dateTime, 
      required this.price, 
      required this.isPaid
      }
    );
}
