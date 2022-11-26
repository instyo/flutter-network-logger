import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'network_event.dart';
import 'network_logger.dart';

class UIDetail extends StatefulWidget {
  final NetworkEvent event;

  static Route<void> route({
    required NetworkEvent event,
    required NetworkEventList eventList,
  }) {
    return MaterialPageRoute(
      builder: (context) => StreamBuilder(
        stream: eventList.stream.where((item) => item.event == event),
        builder: (context, snapshot) => UIDetail(event: event),
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

  const UIDetail({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<UIDetail> createState() => _UIDetailState();
}

class _UIDetailState extends State<UIDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _index = 0;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late PersistentBottomSheetController _bottomSheetController;

  String textCopy = "";
  final _jsonEncoder = JsonEncoder.withIndent('   ');

  dynamic encodeMap(dynamic data) => _jsonEncoder.convert(data);

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
  void initState() {
    super.initState();
    textCopy = """
Url : ${widget.event.request?.uri} \n

Method : ${widget.event.request?.method} \n

${widget.event.request?.headers != null ? '\nHeaders : \n' + encodeMap(widget.event.request?.headers) : ''}

${widget.event.request?.data != null ? '\nPayload : \n' + encodeMap(widget.event.request?.data) : ''}

${widget.event.response != null ? '\nResponse : \n' + encodeMap(widget.event.response?.data) : ''}

${widget.event.error != null ? '\nError : \n' + encodeMap(widget.event.error?.data) : ''}

""";

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
                            title: Text("Copy as text"),
                            trailing: Icon(Icons.copy_all),
                          ),
                          ListTile(
                            onTap: () async {
                              _bottomSheetController.close();
                              final file = await FileSaver.writeFile(
                                "${widget.event.timestamp?.millisecondsSinceEpoch}",
                                textCopy,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Saved on : ${file.path}"),
                                  action: SnackBarAction(
                                    label: "open",
                                    onPressed: () async {
                                      await OpenFilex.open(file.path);
                                    },
                                  ),
                                ),
                              );
                            },
                            title: Text("Save as file"),
                            trailing: Icon(Icons.save_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.share_outlined),
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
                    color: getColor(widget.event.request?.method ?? "")
                        .withOpacity(.5),
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                trailing: widget.event.status == LogNetworkStatus.loading
                    ? CupertinoActivityIndicator()
                    : widget.event.status == LogNetworkStatus.success
                        ? Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 18,
                          )
                        : Icon(
                            Icons.circle,
                            color: Colors.red,
                            size: 18,
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
          child: JsonViewer(widget.event.request?.queryParameters),
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
                  child: Text("Copy Authorization"),
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
          child: JsonViewer(widget.event.request?.headers),
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
          child: JsonViewer(widget.event.request?.data),
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
              'Status Code : $statusCode',
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
                child: JsonViewer(responseData),
              ),
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
            child: JsonViewer(widget.event.error?.data),
          ),
        ),
      ],
    );
  }
}

class FileSaver {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  static Future<File> writeFile(String filename, String content) async {
    final path = await _localPath;
    final _localFile = File('$path/$filename.txt');
    final file = await _localFile;

    // Write the file
    return file.writeAsString('$content');
  }
}
