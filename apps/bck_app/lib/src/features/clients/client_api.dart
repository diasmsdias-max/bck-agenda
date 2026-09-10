import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import 'client_models.dart';

class ClientApi {
  ClientApi({required String accessToken,Dio? dio}):_dio=dio??Dio(BaseOptions(baseUrl:AppConfig.apiBaseUrl,headers:{'Accept':'application/json','Authorization':'Bearer $accessToken'}));
  final Dio _dio;

  Future<List<ManagedClient>> list({String query='',bool includeInactive=false}) async {
    final r=await _dio.get<List<dynamic>>('/api/v1/clients',queryParameters:{'q':query,'includeInactive':includeInactive});
    return r.data!.map((e)=>ManagedClient.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<ManagedClient> get(String id) async => ManagedClient.fromJson((await _dio.get<Map<String,dynamic>>('/api/v1/clients/$id')).data!);
  Future<List<ClientDuplicate>> duplicates(String phone,{String? excludeId}) async {
    final r=await _dio.get<List<dynamic>>('/api/v1/clients/duplicates',queryParameters:{'phone':phone,'excludeId':excludeId});
    return r.data!.map((e)=>ClientDuplicate.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<ManagedClient> create({required String name,required String phone,bool whatsAppEnabled=true,String? notes,DateTime? birthDate}) async => ManagedClient.fromJson((await _dio.post<Map<String,dynamic>>('/api/v1/clients',data:{'name':name,'phone':phone,'whatsAppEnabled':whatsAppEnabled,'notes':notes,'birthDate':birthDate?.toIso8601String().split('T').first})).data!);
  Future<void> update(ManagedClient client,{required String name,required String phone,required bool whatsAppEnabled,String? notes,DateTime? birthDate}) async => _dio.put<void>('/api/v1/clients/${client.id}',data:{'name':name,'phone':phone,'whatsAppEnabled':whatsAppEnabled,'notes':notes,'birthDate':birthDate?.toIso8601String().split('T').first,'version':client.version});
  Future<List<ClientHistoryItem>> history(String id) async {
    final r=await _dio.get<List<dynamic>>('/api/v1/clients/$id/history');
    return r.data!.map((e)=>ClientHistoryItem.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<String> remove(String id) async => ((await _dio.delete<Map<String,dynamic>>('/api/v1/clients/$id')).data!['result'] as String);
  Future<void> reactivate(String id) async => _dio.post<void>('/api/v1/clients/$id/reactivate');
}
