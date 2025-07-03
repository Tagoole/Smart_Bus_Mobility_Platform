import 'package:flutter/material.dart';

class TransformLatLngToAddress extends StatefulWidget {

  @override
  State<TransformLatLngToAddress> createState() => _TransformLatLngToAddressState();
}

class _TransformLatLngToAddressState extends State<TransformLatLngToAddress> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange,Colors.teal],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0,1.0],
          tileMode: TileMode.clamp
          )
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: (){},
              child: Padding(padding:EdgeInsets.all(20)),
            ),
          ],
        ),
      ),
    );
  }
}