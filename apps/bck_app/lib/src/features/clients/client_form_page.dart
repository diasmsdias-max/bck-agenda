import 'package:flutter/material.dart';
import 'client_api.dart';
import 'client_models.dart';

class ClientFormPage extends StatefulWidget {
  const ClientFormPage({super.key,required this.api,this.client});
  final ClientApi api;
  final ManagedClient? client;
  @override State<ClientFormPage> createState()=>_ClientFormPageState();
}
class _ClientFormPageState extends State<ClientFormPage>{
  final _form=GlobalKey<FormState>(); late final TextEditingController _name,_phone,_notes,_birth; bool _whats=true,_saving=false;
  @override void initState(){super.initState();final c=widget.client;_name=TextEditingController(text:c?.name??'');_phone=TextEditingController(text:c?.phone??'');_notes=TextEditingController(text:c?.notes??'');_birth=TextEditingController(text:c?.birthDate?.toIso8601String().split('T').first??'');_whats=c?.whatsAppEnabled??true;}
  @override void dispose(){_name.dispose();_phone.dispose();_notes.dispose();_birth.dispose();super.dispose();}
  void _message(String text){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> _save()async{
    if(!_form.currentState!.validate())return;
    setState(()=>_saving=true);
    try{
      final duplicates=await widget.api.duplicates(_phone.text,excludeId:widget.client?.id);
      if(duplicates.isNotEmpty&&mounted){
        final proceed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Telefone já cadastrado'),content:Text('Existe um cliente com este telefone: ${duplicates.first.name}. Verifique antes de continuar.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Voltar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Continuar'))]))??false;
        if(!proceed)return;
      }
      final birth=_birth.text.trim().isEmpty?null:DateTime.tryParse(_birth.text.trim());
      if(widget.client==null){await widget.api.create(name:_name.text.trim(),phone:_phone.text.trim(),whatsAppEnabled:_whats,notes:_notes.text.trim().isEmpty?null:_notes.text.trim(),birthDate:birth);}
      else{await widget.api.update(widget.client!,name:_name.text.trim(),phone:_phone.text.trim(),whatsAppEnabled:_whats,notes:_notes.text.trim().isEmpty?null:_notes.text.trim(),birthDate:birth);}
      if(mounted)Navigator.pop(context,true);
    }on ClientApiException catch(e){
      if(!mounted)return;
      if(e.code=='CLIENT_PHONE_DUPLICATE')_message('Este telefone já está vinculado a outro cliente desta empresa.');
      else if(e.code=='VERSION_CONFLICT')_message('Este cliente foi alterado em outro aparelho. Volte à ficha, atualize os dados e tente novamente.');
      else _message(e.message);
    }catch(_){if(mounted)_message('Não foi possível salvar o cliente. Verifique os dados e tente novamente.');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.client==null?'Novo cliente':'Editar cliente')),body:Form(key:_form,child:ListView(padding:const EdgeInsets.all(20),children:[TextFormField(controller:_name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nome *',prefixIcon:Icon(Icons.person_outline)),validator:(v)=>v==null||v.trim().isEmpty?'Informe o nome':null),const SizedBox(height:14),TextFormField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefone *',prefixIcon:Icon(Icons.phone_outlined)),validator:(v)=>(v??'').replaceAll(RegExp(r'[^0-9]'),'').length<8?'Informe um telefone válido':null),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Este número possui WhatsApp'),value:_whats,onChanged:(v)=>setState(()=>_whats=v)),const SizedBox(height:8),TextFormField(controller:_birth,keyboardType:TextInputType.datetime,decoration:const InputDecoration(labelText:'Nascimento',hintText:'AAAA-MM-DD',prefixIcon:Icon(Icons.cake_outlined)),validator:(v){if(v==null||v.trim().isEmpty)return null;return DateTime.tryParse(v.trim())==null?'Use a data no formato AAAA-MM-DD':null;}),const SizedBox(height:14),TextFormField(controller:_notes,maxLines:4,decoration:const InputDecoration(labelText:'Observações',alignLabelWithHint:true,prefixIcon:Icon(Icons.notes_outlined))),const SizedBox(height:24),FilledButton.icon(onPressed:_saving?null:_save,icon:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_outlined),label:Text(_saving?'Salvando...':'Salvar cliente'))])));
}
