import 'package:flutter/material.dart';

class Utils {
  static Color getMethodColor(String? method) {
    late Color color;
    switch (method?.toUpperCase()) {
      case "GET":
        color = Colors.green;
        break;
      case "POST":
        color = Colors.orange;
        break;
      case "PUT":
        color = Colors.deepPurple;
        break;
      case "DELETE":
        color = Colors.red;
        break;
      case "PATCH":
        color = Colors.blue;
        break;
      default:
        color = Colors.black;
        break;
    }

    return color.withOpacity(.5);
  }
}
