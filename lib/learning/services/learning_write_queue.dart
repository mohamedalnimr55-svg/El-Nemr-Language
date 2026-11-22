/// Serializes read-modify-write operations on the same persisted key.
///
/// SharedPreferences does not provide transactions. Without serialization,
/// concurrent quiz results or vocabulary saves can overwrite one another.
/// Only writes to the same key wait for each other; independent videos can
/// save in parallel. An exception cannot poison subsequent queued writes.
class LearningWriteQueue {
  const LearningWriteQueue._();

  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() operation) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then<T>((_) => operation());
    final settled = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _tails[key] = settled;
    settled.then((_) {
      if (identical(_tails[key], settled)) {
        _tails.remove(key);
      }
    });
    return result;
  }
}
