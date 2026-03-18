import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/request_record.dart';
import '../db/notes_database.dart';
import '../l10n/app_localizations.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  List<RequestRecord> _requests = [];
  bool _isLoading = true;
  String _domainFilter = '';
  String _methodFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });
    final requests = await DatabaseHelper.instance.readAllRequests();
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  List<RequestRecord> get _filteredRequests {
    return _requests.where((r) {
      bool matchesDomain = _domainFilter.isEmpty || r.url.contains(_domainFilter);
      bool matchesMethod = _methodFilter.isEmpty || r.method == _methodFilter;
      return matchesDomain && matchesMethod;
    }).toList();
  }

  void _showNewRequestDialog({RequestRecord? template}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Template',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('FCM Template'),
                  onTap: () {
                    Navigator.pop(context);
                    _openComposer(useFcmTemplate: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: const Text('Blank Template'),
                  onTap: () {
                    Navigator.pop(context);
                    _openComposer(template: template);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openComposer({bool useFcmTemplate = false, RequestRecord? template}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestComposerPage(
          useFcmTemplate: useFcmTemplate,
          template: template,
        ),
      ),
    );
    _loadRequests();
  }

  Set<String> get _domains {
    return _requests.map((r) {
      try {
        return Uri.parse(r.url).host;
      } catch (_) {
        return '';
      }
    }).where((s) => s.isNotEmpty).toSet();
  }

  Set<String> get _methods {
    return _requests.map((r) => r.method).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.request_api ?? 'Request API'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                InputChip(
                  label: Text(_domainFilter.isEmpty ? 'All Domains' : _domainFilter),
                  avatar: const Icon(Icons.public, size: 18),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Domain'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('All Domains'),
                                onTap: () {
                                  setState(() => _domainFilter = '');
                                  Navigator.pop(context);
                                },
                              ),
                              ..._domains.map((d) => ListTile(
                                title: Text(d),
                                onTap: () {
                                  setState(() => _domainFilter = d);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  onDeleted: _domainFilter.isEmpty ? null : () => setState(() => _domainFilter = ''),
                ),
                const SizedBox(width: 8),
                InputChip(
                  label: Text(_methodFilter.isEmpty ? 'All Methods' : _methodFilter),
                  avatar: const Icon(Icons.http, size: 18),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Method'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('All Methods'),
                                onTap: () {
                                  setState(() => _methodFilter = '');
                                  Navigator.pop(context);
                                },
                              ),
                              ..._methods.map((m) => ListTile(
                                title: Text(m),
                                onTap: () {
                                  setState(() => _methodFilter = m);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  onDeleted: _methodFilter.isEmpty ? null : () => setState(() => _methodFilter = ''),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRequests[index];
                      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getMethodColor(record.method),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  record.method,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  record.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(date.toString().split('.')[0]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RequestDetailPage(record: record),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showNewRequestDialog(template: record);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewRequestDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return Colors.blue;
      case 'POST': return Colors.green;
      case 'PUT': return Colors.orange;
      case 'DELETE': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class RequestComposerPage extends StatefulWidget {
  final bool useFcmTemplate;
  final RequestRecord? template;

  const RequestComposerPage({super.key, this.useFcmTemplate = false, this.template});

  @override
  State<RequestComposerPage> createState() => _RequestComposerPageState();
}

class _RequestComposerPageState extends State<RequestComposerPage> {
  String _method = 'GET';
  final _urlController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<Map<String, TextEditingController>> _headers = [];
  bool _isJsonMode = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initTemplate();
  }

  Future<void> _initTemplate() async {
    if (widget.template != null) {
      _method = widget.template!.method;
      _urlController.text = widget.template!.url;
      _bodyController.text = widget.template!.body;
      
      try {
        final Map<String, dynamic> headersMap = json.decode(widget.template!.headers);
        for (var entry in headersMap.entries) {
          _headers.add({
            'key': TextEditingController(text: entry.key),
            'value': TextEditingController(text: entry.value.toString()),
          });
        }
      } catch (_) {}
    } else if (widget.useFcmTemplate) {
      _method = 'POST';
      final prefs = await SharedPreferences.getInstance();
      String rawUrl = prefs.getString('backend_url') ?? '';
      String cleanUrl = rawUrl.replaceAll(RegExp(r'^https?://'), '');
      bool useHttps = prefs.getBool('backend_https') ?? true;
      _urlController.text = useHttps ? 'https://$cleanUrl' : 'http://$cleanUrl';

      String authKey = prefs.getString('backend_auth') ?? '';
      if (authKey.isNotEmpty) {
        _headers.add({
          'key': TextEditingController(text: 'Authorization'),
          'value': TextEditingController(text: authKey),
        });
      }
      
      _bodyController.text = '''{
  "action": "message",
  "service": "FCMBox Request",
  "overview": "This is a test request",
  "data": "This is a test data",
  "image": "https://apac-east1-i.wepayto.win/MD3/check_circle.png"
}''';
    }

    _ensureEmptyHeaderRow();
    setState(() {});
  }

  void _ensureEmptyHeaderRow() {
    if (_headers.isEmpty || _headers.last['key']!.text.isNotEmpty || _headers.last['value']!.text.isNotEmpty) {
      _headers.add({
        'key': TextEditingController(),
        'value': TextEditingController(),
      });
    }
  }

  Map<String, String> _getHeadersMap() {
    Map<String, String> map = {};
    for (var h in _headers) {
      final k = h['key']!.text.trim();
      final v = h['value']!.text.trim();
      if (k.isNotEmpty) {
        map[k] = v;
      }
    }
    if (_isJsonMode && _method != 'GET' && _method != 'HEAD') {
      map['Content-Type'] = 'application/json';
    }
    return map;
  }

  Future<void> _sendRequest() async {
    setState(() => _isSending = true);
    try {
      final urlStr = _urlController.text.trim();
      if (urlStr.isEmpty) throw Exception('URL cannot be empty');
      
      final uri = Uri.parse(urlStr);
      final headersMap = _getHeadersMap();
      http.Response response;

      switch (_method) {
        case 'GET':
          response = await http.get(uri, headers: headersMap);
          break;
        case 'POST':
          response = await http.post(uri, headers: headersMap, body: _bodyController.text);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headersMap, body: _bodyController.text);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headersMap, body: _bodyController.text);
          break;
        default:
          throw Exception('Unsupported method');
      }

      final record = RequestRecord(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        url: urlStr,
        method: _method,
        headers: json.encode(headersMap),
        body: _bodyController.text,
      );
      
      await DatabaseHelper.instance.insertRequest(record);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Response: ${response.statusCode}')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Request'),
        actions: [
          if (_isSending)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            ))
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendRequest,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _method,
                  items: ['GET', 'POST', 'PUT', 'DELETE'].map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _method = v);
                  },
                  underline: const SizedBox(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://api.example.com',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Headers'),
                      Tab(text: 'Body'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView.builder(
                          itemCount: _headers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _headers[index]['key'],
                                      decoration: const InputDecoration(hintText: 'Key', isDense: true),
                                      onChanged: (_) => _ensureEmptyHeaderRow(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _headers[index]['value'],
                                      decoration: const InputDecoration(hintText: 'Value', isDense: true),
                                      onChanged: (_) => _ensureEmptyHeaderRow(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: index == _headers.length - 1 && _headers[index]['key']!.text.isEmpty && _headers[index]['value']!.text.isEmpty 
                                      ? null 
                                      : () {
                                          setState(() {
                                            _headers.removeAt(index);
                                            _ensureEmptyHeaderRow();
                                          });
                                        },
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('JSON'),
                                Switch(
                                  value: _isJsonMode,
                                  onChanged: (v) => setState(() => _isJsonMode = v),
                                ),
                                const Text('RAW'),
                                const SizedBox(width: 16),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _bodyController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: const InputDecoration(
                                    hintText: 'Request Body',
                                    border: OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestDetailPage extends StatelessWidget {
  final RequestRecord record;

  const RequestDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('URL', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(record.url),
          const Divider(),
          const Text('Method', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(record.method),
          const Divider(),
          const Text('Headers', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(record.headers),
          const Divider(),
          const Text('Body', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(record.body.isEmpty ? '(Empty)' : record.body),
        ],
      ),
    );
  }
}
