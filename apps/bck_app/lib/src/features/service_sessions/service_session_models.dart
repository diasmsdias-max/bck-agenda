enum ServiceSessionStatus { open, inService, finished, cancelled }

ServiceSessionStatus serviceSessionStatusFromApi(String value) => switch (value.trim().toUpperCase()) {
  'IN_SERVICE' => ServiceSessionStatus.inService,
  'FINISHED' => ServiceSessionStatus.finished,
  'CANCELLED' || 'CANCELED' => ServiceSessionStatus.cancelled,
  _ => ServiceSessionStatus.open,
};

class ServiceSession {
  const ServiceSession({
    required this.id,
    required this.appointmentId,
    required this.professionalUserId,
    required this.clientName,
    required this.status,
    required this.subtotal,
    required this.discountTotal,
    required this.total,
    required this.createdAt,
    this.clientId,
    this.clientPhone,
    this.notes,
    this.finishedAt,
  });

  final String id;
  final String appointmentId;
  final String professionalUserId;
  final String? clientId;
  final String clientName;
  final String? clientPhone;
  final ServiceSessionStatus status;
  final String? notes;
  final double subtotal;
  final double discountTotal;
  final double total;
  final DateTime createdAt;
  final DateTime? finishedAt;

  bool get isClosed => status == ServiceSessionStatus.finished || status == ServiceSessionStatus.cancelled;

  factory ServiceSession.fromJson(Map<String, dynamic> json) => ServiceSession(
        id: json['id'] as String,
        appointmentId: json['appointmentId'] as String,
        professionalUserId: json['professionalUserId'] as String,
        clientId: json['clientId'] as String?,
        clientName: json['clientName'] as String,
        clientPhone: json['clientPhone'] as String?,
        status: serviceSessionStatusFromApi(json['status'] as String),
        notes: json['notes'] as String?,
        subtotal: (json['subtotal'] as num).toDouble(),
        discountTotal: (json['discountTotal'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        finishedAt: json['finishedAt'] == null ? null : DateTime.parse(json['finishedAt'] as String),
      );
}

class ServiceSessionItem {
  const ServiceSessionItem({
    required this.id,
    required this.itemType,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineSubtotal,
    required this.lineTotal,
    this.serviceId,
    this.sourceItemId,
  });

  final String id;
  final String itemType;
  final String? serviceId;
  final String? sourceItemId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double lineSubtotal;
  final double lineTotal;

  factory ServiceSessionItem.fromJson(Map<String, dynamic> json) => ServiceSessionItem(
        id: json['id'] as String,
        itemType: json['itemType'] as String,
        serviceId: json['serviceId'] as String?,
        sourceItemId: json['sourceItemId'] as String?,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        lineSubtotal: (json['lineSubtotal'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num).toDouble(),
      );
}
