/// One thing the coach may remember (users/{uid}/memory_facts/{id}; spec 9.8,
/// FR-CNV-05; T-AGT-05b, D-101). The Memory Agent (server) proposes facts;
/// only the person keeps or deletes them.
enum MemoryStatus { proposed, saved, deleted }

class MemoryFact {
  const MemoryFact({
    required this.id,
    required this.fact,
    required this.category,
    required this.sensitive,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String fact;

  /// preference, routine, barrier, win, goal, physical, or one of the
  /// sensitive ones: medication, diagnosis, mental_health.
  final String category;

  /// A health detail (medicine, condition, mental health): kept only with
  /// the `memory_sensitive` consent.
  final bool sensitive;
  final MemoryStatus status;
  final DateTime? createdAt;

  static const sensitiveCategories = {
    'medication',
    'diagnosis',
    'mental_health',
  };

  /// Parses a stored document ([createdAt] already converted by the
  /// repository). Returns null for anything malformed or deleted: deleted
  /// facts are never shown again.
  static MemoryFact? fromMap(
    String id,
    Map<String, dynamic>? data, {
    DateTime? createdAt,
  }) {
    if (data == null) return null;
    final status = switch (data['status']) {
      'proposed' => MemoryStatus.proposed,
      'saved' => MemoryStatus.saved,
      _ => null,
    };
    final fact = data['fact'];
    final category = data['category'];
    if (status == null ||
        fact is! String ||
        fact.isEmpty ||
        category is! String) {
      return null;
    }
    return MemoryFact(
      id: id,
      fact: fact,
      category: category,
      // Sensitive if either the server flag or the category says so.
      sensitive:
          data['sensitive'] == true || sensitiveCategories.contains(category),
      status: status,
      createdAt: createdAt,
    );
  }
}

/// Whether the person may keep [fact] right now. Deleting is always allowed.
enum KeepBlock { none, memoryOff, needsSensitiveOptIn }

KeepBlock keepBlock(
  MemoryFact fact, {
  required bool memoryOn,
  required bool sensitiveOn,
}) {
  if (!memoryOn) return KeepBlock.memoryOff;
  if (fact.sensitive && !sensitiveOn) return KeepBlock.needsSensitiveOptIn;
  return KeepBlock.none;
}
