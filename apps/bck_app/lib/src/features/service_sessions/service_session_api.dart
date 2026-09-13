import 'dart:math';
import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import 'service_session_models.dart';

class ServiceSessionApi {
  ServiceSessionApi({Dio? dio}):_dio=dio??Dio(BaseOptions(baseUrl:AppConfig.apiBaseUrl,connectTimeout:const Duration(seconds:10),receiveTimeout:const Duration(seconds:10),headers:const{'Accept':'application/json'}));
  final Dio _dio; String? _accessToken; final Random _random=Random.secure();
  void setAccessToken(String? token)=>_accessToken=token;
  Options _authorized({String? idempotencyKey})=>Options(headers:{if(_accessToken!=null)'Authorization':'Bearer $_accessToken',if(idempotencyKey!=null)'Idempotency-Key':idempotencyKey});
  String newIdempotencyKey(){final timestamp=DateTime.now().microsecondsSinceEpoch.toRadixString(36);final entropy=List.generate(16,(_)=>_random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();return'bck-$timestamp-$entropy';}
  Future<ServiceSession> open({required String appointmentId,String? notes,String? idempotencyKey})async{final response=await _dio.post<Map<String,dynamic>>('/api/v1/service-sessions',data:{'appointmentId':appointmentId,'notes':notes},options:_authorized(idempotencyKey:idempotencyKey??newIdempotencyKey()));return ServiceSession.fromJson(response.data!);}
  Future<ServiceSession> get(String id)async{final response=await _dio.get<Map<String,dynamic>>('/api/v1/service-sessions/$id',options:_authorized());return ServiceSession.fromJson(response.data!);}
  Future<List<ServiceSessionHistory>> getHistory(String id) async { final response=await _dio.get<List<dynamic>>('/api/v1/service-sessions/$id/history',options:_authorized()); return response.data!.map((item)=>ServiceSessionHistory.fromJson(Map<String,dynamic>.from(item as Map))).toList(growable:false); }
  Future<ServiceSession?> getByAppointment(String appointmentId)async{try{final response=await _dio.get<Map<String,dynamic>>('/api/v1/appointments/$appointmentId/service-session',options:_authorized());return ServiceSession.fromJson(response.data!);}on DioException catch(error){if(error.response?.statusCode==404)return null;rethrow;}}
  Future<ServiceSessionItem> addItem(String sessionId,{required String itemType,String? serviceId,String? sourceItemId,required String name,required double quantity,required double unitPrice,double discountAmount=0,String? idempotencyKey})async{final response=await _dio.post<Map<String,dynamic>>('/api/v1/service-sessions/$sessionId/items',data:{'itemType':itemType,'serviceId':serviceId,'sourceItemId':sourceItemId,'name':name,'quantity':quantity,'unitPrice':unitPrice,'discountAmount':discountAmount},options:_authorized(idempotencyKey:idempotencyKey??newIdempotencyKey()));return ServiceSessionItem.fromJson(response.data!);}
  Future<ServiceSession> finish(String sessionId,{String? notes,String? idempotencyKey})async{final response=await _dio.post<Map<String,dynamic>>('/api/v1/service-sessions/$sessionId/finish',data:{'notes':notes},options:_authorized(idempotencyKey:idempotencyKey??newIdempotencyKey()));return ServiceSession.fromJson(response.data!);}
}
