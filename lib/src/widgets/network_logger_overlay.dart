import 'package:dio_network_logger/src/widgets/network_logger_button.dart';
import 'package:flutter/material.dart';

class NetworkLoggerOverlay extends StatefulWidget {
  static const double _defaultPadding = 30;

  final double bottom;
  final double right;
  final bool draggable;
  final Color color;

  const NetworkLoggerOverlay({
    super.key,
    required this.right,
    required this.bottom,
    required this.draggable,
    this.color = Colors.deepPurple,
  });

  /// Attach overlay to specified [context]. The FAB will be draggable unless
  /// [draggable] set to `false`. Initial distance from the button to the screen
  /// edge can be configured using [bottom] and [right] parameters.
  static OverlayEntry attachTo(
    BuildContext context, {
    bool rootOverlay = true,
    double bottom = _defaultPadding,
    double right = _defaultPadding,
    bool draggable = true,
    Color color = Colors.deepPurple,
  }) {
    // create overlay entry
    final entry = OverlayEntry(
      builder: (context) => NetworkLoggerOverlay(
        bottom: bottom,
        right: right,
        draggable: draggable,
        color: color,
      ),
    );
    // insert on next frame
    Future.delayed(Duration.zero, () {
      final overlay = Overlay.of(context, rootOverlay: rootOverlay);

      overlay.insert(entry);
    });
    // return
    return entry;
  }

  @override
  State<NetworkLoggerOverlay> createState() => _NetworkLoggerOverlayState();
}

class _NetworkLoggerOverlayState extends State<NetworkLoggerOverlay> {
  static const Size buttonSize = Size(57, 57);

  late double bottom = widget.bottom;
  late double right = widget.right;

  late MediaQueryData screen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screen = MediaQuery.of(context);
  }

  Offset? lastPosition;

  void onPanUpdate(LongPressMoveUpdateDetails details) {
    final delta = lastPosition! - details.localPosition;

    bottom += delta.dy;
    right += delta.dx;

    lastPosition = details.localPosition;

    /// Checks if the button went of screen
    if (bottom < 0) {
      bottom = 0;
    }

    if (right < 0) {
      right = 0;
    }

    if (bottom + buttonSize.height > screen.size.height) {
      bottom = screen.size.height - buttonSize.height;
    }

    if (right + buttonSize.width > screen.size.width) {
      right = screen.size.width - buttonSize.width;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.draggable) {
      return Positioned(
        right: right,
        bottom: bottom,
        child: GestureDetector(
          onLongPressMoveUpdate: onPanUpdate,
          onLongPressUp: () {
            setState(() => lastPosition = null);
          },
          onLongPressDown: (details) {
            setState(() => lastPosition = details.localPosition);
          },
          child: Material(
            elevation: lastPosition == null ? 0 : 30,
            borderRadius: BorderRadius.all(Radius.circular(buttonSize.width)),
            child: NetworkLoggerButton(),
          ),
        ),
      );
    }

    return Positioned(
      right: widget.right + screen.padding.right,
      bottom: widget.bottom + screen.padding.bottom,
      child: NetworkLoggerButton(),
    );
  }
}
