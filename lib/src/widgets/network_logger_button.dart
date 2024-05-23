import 'dart:async';
import 'package:dio_network_logger/src/utils/network_logger.dart';
import 'package:dio_network_logger/src/widgets/requests_list_screen.dart';
import 'package:flutter/material.dart';

/// [FloatingActionButton] that opens [NetworkLoggerScreen] when pressed.
class NetworkLoggerButton extends StatefulWidget {
  /// Source event list (default: [NetworkLogger.instance])
  final NetworkEventList eventList;

  /// Blink animation period
  final Duration blinkPeriod;

  // Button background color
  final Color color;

  /// If set to true this button will be hidden on non-debug builds.
  final bool showOnlyOnDebug;

  NetworkLoggerButton({
    super.key,
    this.color = Colors.deepPurple,
    this.blinkPeriod = const Duration(seconds: 1, microseconds: 500),
    this.showOnlyOnDebug = false,
    NetworkEventList? eventList,
  }) : eventList = eventList ?? NetworkLogger.instance;

  @override
  State<NetworkLoggerButton> createState() => _NetworkLoggerButtonState();
}

class _NetworkLoggerButtonState extends State<NetworkLoggerButton> {
  StreamSubscription? _subscription;
  Timer? _blinkTimer;
  bool _visible = true;
  int _blink = 0;

  Future<void> _press() async {
    setState(() {
      _visible = false;
    });
    try {
      await RequestsListScreen.open(context, eventList: widget.eventList);
    } finally {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant NetworkLoggerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventList != widget.eventList) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.eventList.stream.listen((event) {
      if (mounted) {
        setState(() {
          _blink = _blink % 2 == 0 ? 6 : 5;
        });
      }
    });
  }

  @override
  void initState() {
    _subscribe();
    _blinkTimer = Timer.periodic(widget.blinkPeriod, (timer) {
      if (_blink > 0 && mounted) {
        setState(() {
          _blink--;
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox();
    }

    return FloatingActionButton(
      onPressed: _press,
      backgroundColor: widget.color,
      child: Icon(
        (_blink % 2 == 0) ? Icons.cloud : Icons.cloud_queue,
        color: Colors.white,
      ),
    );
  }
}
