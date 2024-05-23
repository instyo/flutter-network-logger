import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';
import 'package:network_logger/dio_network_logger.dart';
import 'package:network_logger/src/utils/network_event.dart';
import 'package:network_logger/src/utils/utils.dart';

class RequestDetailScreen extends StatefulWidget {
  final NetworkEvent event;

  static Route<void> route({
    required NetworkEvent event,
    required NetworkEventList eventList,
  }) {
    return MaterialPageRoute(
      builder: (context) => StreamBuilder(
        stream: eventList.stream.where((item) => item.event == event),
        builder: (context, snapshot) => RequestDetailScreen(event: event),
      ),
    );
  }

  /// Opens screen.
  static Future<void> open(
    BuildContext context,
    NetworkEvent event,
    NetworkEventList eventList,
  ) {
    return Navigator.of(context).push(route(
      event: event,
      eventList: eventList,
    ));
  }

  const RequestDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _index = 0;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late PersistentBottomSheetController _bottomSheetController;
  final _jsonEncoder = const JsonEncoder.withIndent('   ');

  dynamic encodeMap(dynamic data) => _jsonEncoder.convert(data);

  bool isValidJson(dynamic str) {
    return str is Map || str is List;
  }

  String get textCopy {
    return """
Url : ${widget.event.request?.uri} \n
Method : ${widget.event.request?.method} \n
${widget.event.request?.headers != null ? '\nHeaders : \n${encodeMap(widget.event.request?.headers)}' : ''}
${widget.event.request?.data != null ? '\nPayload : \n${encodeMap(widget.event.request?.data)}' : ''}
${widget.event.response != null ? '\nResponse : \n${encodeMap(widget.event.response?.data)}' : ''}
${widget.event.error != null ? '\nError : \n${encodeMap(widget.event.error?.data)}' : ''}
""";
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      initialIndex: _index,
      length: 2,
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _index = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: const Text('Detail'),
          actions: [
            IconButton(
              onPressed: () {
                _bottomSheetController =
                    scaffoldKey.currentState!.showBottomSheet(
                  (context) => Container(
                    color: Colors.grey.shade200,
                    height: 150,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            height: 5,
                            width: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.black,
                            ),
                          ),
                          ListTile(
                            onTap: () async {
                              _bottomSheetController.close();
                              await copyText(context, textCopy);
                            },
                            title: const Text("Copy as text"),
                            trailing: const Icon(Icons.copy_all),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined),
            )
          ],
        ),
        body: SizedBox.expand(
          child: Column(
            children: [
              ListTile(
                onTap: () async {
                  await copyText(
                    context,
                    widget.event.request?.uri ?? "",
                  );
                },
                leading: Container(
                  decoration: BoxDecoration(
                    color: Utils.getMethodColor(widget.event.request?.method),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    widget.event.request?.method ?? "",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  widget.event.request?.uri ?? "-",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                trailing: widget.event.status == LogNetworkStatus.loading
                    ? const CupertinoActivityIndicator()
                    : widget.event.status == LogNetworkStatus.success
                        ? const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 14,
                          )
                        : const Icon(
                            Icons.circle,
                            color: Colors.red,
                            size: 14,
                          ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                indicatorColor: Colors.black,
                tabs: const [
                  Tab(
                    text: 'Request',
                  ),
                  Tab(
                    text: 'Response',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestView(context),
                    _buildResponse(),
                  ],
                ),
              ),
              const SizedBox(height: 20)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTitle({
    required String title,
    Widget? toggleCode,
    VoidCallback? onCopy,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          toggleCode ?? const SizedBox(),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(
                Icons.copy,
              ),
            )
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.all(15).copyWith(top: 0),
      child: child,
    );
  }

  Widget _buildQueryParams(BuildContext context) {
    if ((widget.event.request?.queryParameters ?? {}).isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 10,
        ),
        _buildActionTitle(
          title: 'Query Parameters',
        ),
        const SizedBox(
          height: 10,
        ),
        _buildCard(
          child: isValidJson(widget.event.request?.queryParameters)
              ? JsonViewer(widget.event.request?.queryParameters)
              : Text('${widget.event.request?.queryParameters}'),
        ),
      ],
    );
  }

  Widget _buildHeaders(BuildContext context) {
    final token = "${widget.event.request?.headers?["authorization"]}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionTitle(
          title: 'Headers',
          toggleCode: token.isEmpty
              ? const SizedBox()
              : TextButton(
                  child: const Text("Copy Authorization"),
                  onPressed: () async {
                    await copyText(
                      context,
                      "${widget.event.request?.headers?["authorization"]}",
                    );
                  },
                ),
          onCopy: () async {
            await copyText(
              context,
              encodeMap(widget.event.request?.headers),
            );
          },
        ),
        _buildCard(
          child: isValidJson(widget.event.request?.headers)
              ? JsonViewer(widget.event.request?.headers)
              : Text('${widget.event.request?.headers}'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (widget.event.request?.data == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionTitle(
          title: 'Body',
          onCopy: () async {
            await copyText(
              context,
              encodeMap(widget.event.request?.data),
            );
          },
        ),
        _buildCard(
          child: isValidJson(widget.event.request?.data)
              ? JsonViewer(widget.event.request?.data)
              : Text('${widget.event.request?.data}'),
        ),
      ],
    );
  }

  Widget _buildUrlInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 20,
        ),
        _buildActionTitle(
          title: 'URI',
        ),
        const SizedBox(
          height: 10,
        ),
        _buildCard(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Url',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                Text(widget.event.request?.baseUrl ?? "-"),
                const SizedBox(height: 15),
                const Text(
                  'Path',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                Text(widget.event.request?.path ?? "-"),
              ],
            ),
          ),
        ),
        _buildQueryParams(context),
      ],
    );
  }

  Widget _buildRequestView(BuildContext context) {
    return ListView(
      children: [
        _buildUrlInfo(),
        _buildHeaders(context),
        _buildBody(),
      ],
    );
  }

  Future<void> copyText(BuildContext context, String text) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isEmpty ? "Data is empty!" : "Copied",
        ),
      ),
    );

    if (text.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );
  }

  Widget _buildResponse() {
    return ListView(
      children: [
        _buildData(),
      ],
    );
  }

  Widget _buildData() {
    final statusCode = widget.event.response?.statusCode.toString() ?? '';
    final responseData = widget.event.response?.data ?? {};

    if (widget.event.response == null ||
        widget.event.status == LogNetworkStatus.error) {
      return _buildError();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 20,
        ),
        _buildActionTitle(
          title: 'Response Status',
        ),
        const SizedBox(
          height: 10,
        ),
        _buildCard(
          child: SizedBox(
            width: double.maxFinite,
            child: Text(
              'Status Code : $statusCode\n\nRequest Time : ${widget.event.timeRequest} ms',
            ),
          ),
        ),
        responseData.isEmpty
            ? const SizedBox()
            : _buildActionTitle(
                title: 'Data',
                onCopy: () async {
                  await copyText(context, encodeMap(responseData));
                },
              ),
        responseData.isEmpty
            ? const SizedBox()
            : _buildCard(
                child: isValidJson(responseData)
                    ? JsonViewer(responseData)
                    : Text('$responseData')),
      ],
    );
  }

  Widget _buildError() {
    final errorMessage = widget.event.error?.message ?? "";
    final message = errorMessage.isEmpty ? 'N/A' : errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionTitle(
          title: 'Status',
        ),
        const SizedBox(
          height: 5,
        ),
        _buildCard(
          child: SizedBox(
            width: double.maxFinite,
            child: Text(message),
          ),
        ),
        _buildActionTitle(
          title: 'Response',
          onCopy: () async {
            await copyText(
              context,
              encodeMap(widget.event.error?.data),
            );
          },
        ),
        _buildCard(
          child: SizedBox(
            width: double.maxFinite,
            child: isValidJson(widget.event.error?.data)
                ? JsonViewer(widget.event.error?.data)
                : Text('${widget.event.error?.data}'),
          ),
        ),
      ],
    );
  }
}
