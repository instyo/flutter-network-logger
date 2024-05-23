import 'package:flutter/material.dart';
import 'package:network_logger/dio_network_logger.dart';
import 'package:network_logger/src/utils/enumerate_items.dart';
import 'package:network_logger/src/utils/network_event.dart';
import 'package:network_logger/src/utils/utils.dart';

class RequestsListScreen extends StatefulWidget {
  final NetworkEventList eventList;

  RequestsListScreen({
    super.key,
    NetworkEventList? eventList,
  }) : eventList = eventList ?? NetworkLogger.instance;

  static Future<void> open(
    BuildContext context, {
    NetworkEventList? eventList,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestsListScreen(eventList: eventList),
      ),
    );
  }

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  late TextEditingController searchController;

  List<NetworkEvent> getEvents() {
    if (searchController.text.isEmpty) {
      return widget.eventList.events;
    }

    final String query = searchController.text.toLowerCase();
    return widget.eventList.events
        .where((it) => it.request?.uri.toLowerCase().contains(query) ?? false)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Logs'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => widget.eventList.clear(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: widget.eventList.stream,
        builder: (context, snapshot) {
          // filter events with search keyword
          final events = getEvents();

          return Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: (text) {
                  widget.eventList.updated(NetworkEvent());
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
                        ? Text('${getEvents().length} results')
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
                        onTap: () => RequestDetailScreen.open(
                          context,
                          item,
                          widget.eventList,
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
                                            color: Utils.getMethodColor(
                                              item.request?.method,
                                            ),
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
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.dateFormat,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.timelapse_rounded,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${item.timeRequest} ms',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
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
