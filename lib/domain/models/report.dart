/// What a user report points at.
enum ReportTarget {
  user('user'),
  activity('activity'),
  message('message');

  const ReportTarget(this.id);
  final String id;
}

/// Why something was reported. Ids are persisted and checked by the rules.
enum ReportReason {
  harassment('harassment'),
  inappropriate('inappropriate'),
  spam('spam'),
  scam('scam'),
  safety('safety'),
  other('other');

  const ReportReason(this.id);
  final String id;
}
