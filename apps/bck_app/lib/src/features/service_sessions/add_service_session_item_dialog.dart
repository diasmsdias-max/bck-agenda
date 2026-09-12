import 'package:flutter/material.dart';

class ServiceSessionItemDraft {
  const ServiceSessionItemDraft({required this.name, required this.quantity, required this.unitPrice, required this.discountAmount});
  final String name;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
}

class AddServiceSessionItemDialog extends StatefulWidget {
  const AddServiceSessionItemDialog({super.key});

  @override
  State<AddServiceSessionItemDialog> createState() => _AddServiceSessionItemDialogState();
}

class _AddServiceSessionItemDialogState extends State<AddServiceSessionItemDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _discount = TextEditingController(text: '0');
  String? _error;

  double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  void _submit() {
    final quantity = _number(_quantity.text);
    final price = _number(_price.text);
    final discount = _number(_discount.text);
    if (_name.text.trim().isEmpty || quantity == null || quantity <= 0 || price == null || price < 0 || discount == null || discount < 0 || discount > quantity * price) {
      setState(() => _error = 'Confira descrição, quantidade, valor e desconto.');
      return;
    }
    Navigator.pop(context, ServiceSessionItemDraft(name: _name.text.trim(), quantity: quantity, unitPrice: price, discountAmount: discount));
  }

  @override
  void dispose() {
    _name.dispose(); _quantity.dispose(); _price.dispose(); _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adicionar item'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Descrição')),
            TextField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade')),
            TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor unitário')),
            TextField(controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Desconto')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Adicionar')),
        ],
      );
}
