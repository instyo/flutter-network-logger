import 'dart:async';
import 'package:flutter/material.dart';
import 'enumerate_items.dart';
import 'network_event.dart';
import 'network_logger.dart';
import 'ui_detail.dart';

/// Overlay for [NetworkLoggerButton].
class NetworkLoggerOverlay extends StatefulWidget {
  static const double _defaultPadding = 30;

  const NetworkLoggerOverlay._({
    required this.right,
    required this.bottom,
    required this.draggable,
    this.color = Colors.deepPurple,
    Key? key,
  }) : super(key: key);

  final double bottom;
  final double right;
  final bool draggable;
  final Color color;

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
      builder: (context) => NetworkLoggerOverlay._(
        bottom: bottom,
        right: right,
        draggable: draggable,
        color: color,
      ),
    );
    // insert on next frame
    Future.delayed(Duration.zero, () {
      final overlay = Overlay.of(context, rootOverlay: rootOverlay);

      if (overlay == null) {
        throw Exception(
          'FlutterNetworkLogger:  No Overlay widget found. '
          '                       The most common way to add an Overlay to an application is to include a MaterialApp or Navigator above widget that calls NetworkLoggerOverlay.attachTo()',
        );
      }

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
            child: NetworkLoggerButton(
              color: widget.color,
            ),
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
    Key? key,
    this.color = Colors.deepPurple,
    this.blinkPeriod = const Duration(seconds: 1, microseconds: 500),
    this.showOnlyOnDebug = false,
    NetworkEventList? eventList,
  })  : this.eventList = eventList ?? NetworkLogger.instance,
        super(key: key);

  @override
  _NetworkLoggerButtonState createState() => _NetworkLoggerButtonState();
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
      await NetworkLoggerScreen.open(context, eventList: widget.eventList);
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
      child: Icon(
        (_blink % 2 == 0) ? Icons.cloud : Icons.cloud_queue,
        color: Colors.white,
      ),
      onPressed: _press,
      backgroundColor: widget.color,
    );
  }
}

/// Screen that displays log entries list.
class NetworkLoggerScreen extends StatelessWidget {
  NetworkLoggerScreen({Key? key, NetworkEventList? eventList})
      : this.eventList = eventList ?? NetworkLogger.instance,
        super(key: key);

  /// Event list to listen for event changes.
  final NetworkEventList eventList;

  /// Opens screen.
  static Future<void> open(
    BuildContext context, {
    NetworkEventList? eventList,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkLoggerScreen(eventList: eventList),
      ),
    );
  }

  final TextEditingController searchController =
      TextEditingController(text: null);

  /// filte events with search keyword
  List<NetworkEvent> getEvents() {
    if (searchController.text.isEmpty) return eventList.events;

    final query = searchController.text.toLowerCase();
    return eventList.events
        .where((it) => it.request?.uri.toLowerCase().contains(query) ?? false)
        .toList();
  }

  Color getColor(String method) {
    switch (method.toUpperCase()) {
      case "GET":
        return Colors.green;
      case "POST":
        return Colors.orange;
      case "PUT":
        return Colors.deepPurple;
      case "DELETE":
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Network Logs'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => eventList.clear(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: eventList.stream,
        builder: (context, snapshot) {
          // filter events with search keyword
          final events = getEvents();

          return Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: (text) {
                  eventList.updated(NetworkEvent());
                },
                autocorrect: false,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: Colors.black26),
                  suffix: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, value, child) => value.text.isNotEmpty
                        ? Text(getEvents().length.toString() + ' results')
                        : const SizedBox(),
                  ),
                  hintText: "enter keyword to search",
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: enumerateItems<NetworkEvent>(
                    events,
                    (context, item) {
                      return InkWell(
                        key: ValueKey(item.request),
                        onTap: () => UIDetail.open(
                          context,
                          item,
                          eventList,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: getColor(
                                                    item.request?.method ?? "")
                                                .withOpacity(.5),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          child: Text(
                                            item.request?.method ?? "",
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.request?.path ?? "",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.request?.baseUrl ?? "",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.dateFormat,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.error == null
                                      ? (item.response == null)
                                          ? Colors.grey
                                          : Colors.green
                                      : Colors.red,
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
