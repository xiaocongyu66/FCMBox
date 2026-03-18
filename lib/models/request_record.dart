class RequestRecord {
  final int timestamp;
  final String url;
  final String method;
  final String headers;
  final String body;

  RequestRecord({
    required this.timestamp,
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
  });

  factory RequestRecord.fromJson(Map<String, dynamic> json) {
    return RequestRecord(
      timestamp: json['timestamp'] as int,
      url: json['url'] as String,
      method: json['method'] as String,
      headers: json['headers'] as String,
      body: json['body'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'url': url,
      'method': method,
      'headers': headers,
      'body': body,
    };
  }
}
