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
}