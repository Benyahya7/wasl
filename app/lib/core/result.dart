/// `Result<T>` — every load/action returns Ok or Err with a readable message.
/// Nothing fails silently: screens show the error + Retry.
sealed class Result<T> {
  const Result();
  R fold<R>(R Function(T value) onOk, R Function(String message) onErr);
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
  @override
  R fold<R>(R Function(T value) onOk, R Function(String message) onErr) =>
      onOk(value);
}

class Err<T> extends Result<T> {
  final String message;
  const Err(this.message);
  @override
  R fold<R>(R Function(T value) onOk, R Function(String message) onErr) =>
      onErr(message);
}

/// Run a future and convert any failure into an Err with a readable message.
Future<Result<T>> guard<T>(Future<T> Function() run) async {
  try {
    return Ok(await run());
  } catch (e) {
    return Err(_readable(e));
  }
}

String _readable(Object e) {
  final s = e.toString();
  // Strip the "FirebaseException ([code]) " prefix when present.
  final m = RegExp(r'\[[\w/-]+\]\s*(.*)').firstMatch(s);
  if (m != null && (m.group(1) ?? '').isNotEmpty) return m.group(1)!;
  if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
  return s;
}
