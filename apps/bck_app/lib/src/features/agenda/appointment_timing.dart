class AppointmentTiming {
  const AppointmentTiming._();

  static bool isLate({
    required DateTime startsAt,
    required String status,
    DateTime? arrivedAt,
    DateTime? now,
  }) {
    final normalizedStatus = status.trim().toUpperCase();
    if (arrivedAt != null || _startedOrClosed.contains(normalizedStatus)) {
      return false;
    }
    final reference = now ?? DateTime.now();
    return reference.isAfter(startsAt);
  }

  static int? actualDurationMinutes({
    DateTime? serviceStartedAt,
    DateTime? serviceFinishedAt,
  }) {
    if (serviceStartedAt == null || serviceFinishedAt == null) return null;
    final minutes = serviceFinishedAt.difference(serviceStartedAt).inMinutes;
    return minutes < 0 ? null : minutes;
  }

  static const _startedOrClosed = <String>{
    'WAITING',
    'IN_SERVICE',
    'FINISHED',
    'CANCELLED',
    'NO_SHOW',
    'RESCHEDULED',
  };
}
