import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class TransformLatLngToAddress extends StatefulWidget {
  @override
  State<TransformLatLngToAddress> createState() =>
      _TransformLatLngToAddressState();
}

class _TransformLatLngToAddressState extends State<TransformLatLngToAddress> {
  String placeM = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.teal],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, 1.0],
          tileMode: TileMode.clamp,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(placeM),
            GestureDetector(
              onTap: () async {
                List<Placemark> placemark = await placemarkFromCoordinates(
                  0.35364743126561693,
                  32.57339823243943,
                );

                setState(() {
                  placeM = '${placemark.reversed.last.country}' '${placemark.reversed.last.locality}';
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(color: Colors.redAccent),
                  child: Center(child: Text('Hit to Convert.')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
