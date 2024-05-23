import 'package:flutter/material.dart';

class Utils {
  static Color getMethodColor(String? method) {
    late Color color;
    switch (method?.toUpperCase()) {
      case "GET":
        color = Colors.green;
      case "POST":
        color = Colors.orange;
      case "PUT":
        color = Colors.deepPurple;
      case "DELETE":
        color = Colors.red;
      case "PATCH":
        color = Colors.blue;
      default:
        color = Colors.black;
    }

    return color.withOpacity(.5);
  }
}
