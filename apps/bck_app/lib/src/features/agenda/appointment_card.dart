import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import 'agenda_models.dart';
import 'appointment_card_details.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.item,
    this.showDate = false,
    this.onTap,
  });

  final AppointmentItem item;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = AgendaStatus.fromApi(item.status);
    final statusColor = AgendaPalette.forStatus(status);
    final startsAt = item.startsAt.toLocal();
    final endsAt = item.endsAt.toLocal();
    final details = AppointmentCardDetails.build(
      startsAt: item.startsAt,
      status: item.status,
      arrivedAt: item.arrivedAt,
      serviceStartedAt: item.serviceStartedAt,
      serviceFinishedAt: item.serviceFinishedAt,
      actualDurationMinutes: item.actualDurationMinutes,
    );

    String hm(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final prefix = showDate
        ? '${startsAt.day.toString().padLeft(2, '0')}/${startsAt.month.toString().padLeft(2, '0')} • '
        : '';
    final planned =
        '$prefix${hm(startsAt)}–${hm(endsAt)} • ${status.label}${item.isFitIn ? ' • Encaixe' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(status.icon, color: statusColor),
        title: Text(
          item.clientName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(planned),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: details
                    .map(
                      (detail) => Text(
                        detail,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: detail == 'Atrasado'
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.white60,
                              fontWeight: detail == 'Atrasado'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}
