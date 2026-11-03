/// Who wrote a chat line.
enum ChatAuthor { user, coach, system }

/// One line in the Care conversation. Coach answers carry their sources
/// (FR-CNV-04).
class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    this.sources = const [],
  });

  final ChatAuthor author;
  final String text;
  final List<String> sources;
}
