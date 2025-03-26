class Message {
  final String name;
  final String text;
  final String to;
  final DateTime timestamp;

  Message({
    required this.name,
    required this.text,
    required this.to,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      name: json['from'] ?? 'Unknown',
      text: json['text'] ?? '',
      to: json['to'] ?? 'All',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
              : DateTime.parse(json['timestamp']))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': name,
      'text': text,
      'to': to,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}