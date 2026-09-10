class ManagedClient {
  const ManagedClient({required this.id,required this.name,required this.phone,required this.whatsAppEnabled,this.notes,this.birthDate,required this.active,required this.version});
  final String id,name,phone;
  final bool whatsAppEnabled,active;
  final String? notes;
  final DateTime? birthDate;
  final int version;
  factory ManagedClient.fromJson(Map<String,dynamic> j)=>ManagedClient(id:j['id'],name:j['name'],phone:j['phone'],whatsAppEnabled:j['whatsAppEnabled']??true,notes:j['notes'],birthDate:j['birthDate']==null?null:DateTime.parse(j['birthDate']),active:j['active']??true,version:j['version']??1);
}

class ClientDuplicate {
  const ClientDuplicate({required this.id,required this.name,required this.phone,required this.active});
  final String id,name,phone;
  final bool active;
  factory ClientDuplicate.fromJson(Map<String,dynamic> j)=>ClientDuplicate(id:j['id'],name:j['name'],phone:j['phone'],active:j['active']);
}

class ClientHistoryItem {
  const ClientHistoryItem({required this.appointmentId,required this.startsAt,required this.endsAt,required this.status,required this.professionalName,this.serviceName});
  final String appointmentId,status,professionalName;
  final String? serviceName;
  final DateTime startsAt,endsAt;
  factory ClientHistoryItem.fromJson(Map<String,dynamic> j)=>ClientHistoryItem(appointmentId:j['appointmentId'],startsAt:DateTime.parse(j['startsAt']),endsAt:DateTime.parse(j['endsAt']),status:j['status'],professionalName:j['professionalName'],serviceName:j['serviceName']);
}
