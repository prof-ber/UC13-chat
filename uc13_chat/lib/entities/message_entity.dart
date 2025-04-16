class Message {
  final String name;
  final String text;
  final String to;
  final DateTime timestamp;
  final String? fileUrl;
  final double? width;
  final double? height;

  Message({
    required this.name,
    required this.text,
    required this.to,
    required this.timestamp,
    this.fileUrl,
    this.width,
    this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'text': text,
      'to': to,
      'timestamp': timestamp.toIso8601String(),
      'fileUrl': fileUrl,
      'width': width,
      'height': height,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      name: json['name'],
      text: json['text'],
      to: json['to'],
      timestamp: DateTime.parse(json['timestamp']),
      fileUrl: json['fileUrl'],
      width: json['width'],
      height: json['height'],
    );
  }
}
