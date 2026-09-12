import 'appointment_timing.dart';

class AppointmentCardDetails {
  const AppointmentCardDetails._();

  static List<String> build({
    required DateTime startsAt,
    required String status,
    DateTime? arrivedAt,
    DateTime? serviceStartedAt,
    DateTime? serviceFinishedAt,
    int? actualDurationMinutes,
    DateTime? now,
  }) {
    String hm(DateTime value) {
      final local = value.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final details = <String>[];
    if (AppointmentTiming.isLate(
      startsAt: startsAt,
      status: status,
      arrivedAt: arrivedAt,
      now: now,
    )) {
      details.add('Atrasado');
    }
    if (arrivedAt != null) details.add('Chegou ${hm(arrivedAt)}');
    if (serviceStartedAt != null) details.add('Início ${hm(serviceStartedAt)}');
    if (serviceFinishedAt != null) details.add('Fim ${hm(serviceFinishedAt)}');

    final duration = actualDurationMinutes ?? AppointmentTiming.actualDurationMinutes(
      serviceStartedAt: serviceStartedAt,
      serviceFinishedAt: serviceFinishedAt,
    );
    if (duration != null) details.add('Duração real $duration min');
    return details;
  }
}
