import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
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
                FilterChip(
                  label: Text(_domainFilter.isEmpty ? 'All Domains' : _domainFilter),
                  avatar: const Icon(Icons.public, size: 18),
                  selected: _domainFilter.isNotEmpty,
                  onSelected: (_) {
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
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(_methodFilter.isEmpty ? 'All Methods' : _methodFilter),
                  avatar: const Icon(Icons.http, size: 18),
                  selected: _methodFilter.isNotEmpty,
                  onSelected: (_) {
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
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RequestDetailPage(record: record),
                              ),
                            );
                          },
                          onLongPress: () {
                            _openComposer(template: record);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  record.method,
                                  style: TextStyle(
                                    color: _getMethodColor(record.method),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date.toString().split('.')[0],
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 12,
        spaceBetweenChildren: 8,
        overlayColor: Theme.of(context).scaffoldBackgroundColor,
        overlayOpacity: 0.7,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          SpeedDialChild(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: const Icon(Icons.insert_drive_file_outlined),
            label: 'Blank Template',
            labelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            labelBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            labelShadow: [],
            onTap: () => _openComposer(),
          ),
          SpeedDialChild(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: const Icon(Icons.cloud_upload_outlined),
            label: 'FCM Template',
            labelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            labelBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            labelShadow: [],
            onTap: () => _openComposer(useFcmTemplate: true),
          ),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return Colors.green;
      case 'POST': return Colors.orange;
      case 'PUT': return Colors.blue;
      case 'DELETE': return Colors.red;
      case 'PATCH': return Colors.purple;
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

  static const List<String> _commonHeaders = [
    'Accept',
    'Accept-Encoding',
    'Accept-Language',
    'Authorization',
    'Cache-Control',
    'Connection',
    'Content-Length',
    'Content-Type',
    'Cookie',
    'Host',
    'Origin',
    'Referer',
    'User-Agent',
    'X-Requested-With',
  ];

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
      _fillDefaultHeaders();
    } else {
      _fillDefaultHeaders();
    }

    _ensureEmptyHeaderRow();
    setState(() {});
  }

  void _fillDefaultHeaders() {
    _headers.add({
      'key': TextEditingController(text: 'User-Agent'),
      'value': TextEditingController(text: 'FCMBox/1.0'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Accept'),
      'value': TextEditingController(text: '*/*'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Accept-Encoding'),
      'value': TextEditingController(text: 'gzip, deflate, br'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Connection'),
      'value': TextEditingController(text: 'keep-alive'),
    });
  }

  void _ensureEmptyHeaderRow() {
    bool shouldAdd = _headers.isEmpty || _headers.last['key']!.text.isNotEmpty || _headers.last['value']!.text.isNotEmpty;
    if (shouldAdd) {
      if (mounted) {
        setState(() {
          _headers.add({
            'key': TextEditingController(),
            'value': TextEditingController(),
          });
        });
      }
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
        case 'PATCH':
          response = await http.patch(uri, headers: headersMap, body: _bodyController.text);
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
      Fluttertoast.showToast(msg: 'Response: ${response.statusCode}');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // URL Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://api.example.com',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Method Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownMenu<String>(
              initialSelection: _method,
              label: const Text('Method'),
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSelected: (v) {
                if (v != null) setState(() => _method = v);
              },
              dropdownMenuEntries: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].map((m) {
                return DropdownMenuEntry(value: m, label: m);
              }).toList(),
            ),
          ),
          
          const Divider(height: 32),
          
          // Headers Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Headers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _headers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _commonHeaders.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          _headers[index]['key']!.text = selection;
                          _ensureEmptyHeaderRow();
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (textEditingController.text != _headers[index]['key']!.text) {
                            textEditingController.text = _headers[index]['key']!.text;
                          }
                          
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: (val) {
                              _headers[index]['key']!.text = val;
                              _ensureEmptyHeaderRow();
                            },
                            decoration: InputDecoration(
                              hintText: 'Key',
                              isDense: true,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _headers[index]['value'],
                        decoration: InputDecoration(
                          hintText: 'Value',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
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
          
          const Divider(height: 32),
          
          // Body Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Body', style: Theme.of(context).textTheme.titleMedium),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('RAW')),
                    ButtonSegment(value: true, label: Text('JSON')),
                  ],
                  selected: {_isJsonMode},
                  onSelectionChanged: (set) => setState(() => _isJsonMode = set.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _bodyController,
              maxLines: 12,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Request Payload',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 40), // Padding for scrolling
        ],
      ),
    );
  }
}

class RequestDetailPage extends StatelessWidget {
  final RequestRecord record;

  const RequestDetailPage({super.key, required this.record});

  Widget _buildHeadersPreview(BuildContext context) {
    try {
      final Map<String, dynamic> headersMap = json.decode(record.headers);
      if (headersMap.isEmpty) {
        return const Text('(Empty)', style: TextStyle(color: Colors.grey));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: headersMap.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: SelectableText('${e.value}')),
              ],
            ),
          );
        }).toList(),
      );
    } catch (_) {
      return SelectableText(record.headers);
    }
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return Colors.green;
      case 'POST': return Colors.orange;
      case 'PUT': return Colors.blue;
      case 'DELETE': return Colors.red;
      case 'PATCH': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'General',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('URL'),
            subtitle: SelectableText(record.url),
          ),
          ListTile(
            title: const Text('Method'),
            subtitle: SelectableText(
              record.method,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getMethodColor(record.method),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Payload',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Headers'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildHeadersPreview(context),
            ),
          ),
          ListTile(
            title: const Text('Body'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SelectableText(
                record.body.isEmpty ? '(Empty)' : record.body,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
