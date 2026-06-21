import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class ReceiptBuilderExampleScreen extends StatefulWidget {
  const ReceiptBuilderExampleScreen({super.key});

  @override
  State<ReceiptBuilderExampleScreen> createState() =>
      _ReceiptBuilderExampleScreenState();
}

class _ReceiptBuilderExampleScreenState extends State<ReceiptBuilderExampleScreen> {
  final _storeNameController = TextEditingController(text: 'COFFEE SHOP');
  final _items = <Map<String, dynamic>>[
    {'name': 'Latte', 'qty': 2, 'price': 4.50},
    {'name': 'Croissant', 'qty': 1, 'price': 2.75},
    {'name': 'Cappuccino', 'qty': 1, 'price': 5.00},
  ];

  ReceiptBuilder _buildReceipt() {
    final receipt = ReceiptBuilder(maxCharsPerLine: 32)
        .center()
        .bold()
        .doubleWidth()
        .text(_storeNameController.text)
        .normal()
        .doubleWidth()
        .line()
        .text('123 Main Street')
        .text('Tel: (555) 123-4567')
        .feed(lines: 1);

    // Separator
    receipt.line();

    // Date
    final now = DateTime.now();
    receipt.text('Date: ${now.toString().substring(0, 19)}');
    receipt.text('Cashier: John');
    receipt.text('Order #${DateTime.now().millisecondsSinceEpoch % 10000}');
    receipt.feed(lines: 1);
    receipt.line();

    // Items
    for (final item in _items) {
      receipt.text(item['name'] as String);
      final total = (item['qty'] as int) * (item['price'] as double);
      receipt.right().text('${item['qty']} x \$${item['price'].toStringAsFixed(2)}');
      receipt.left().row(
        left: '',
        right: '\$${total.toStringAsFixed(2)}',
      );
      receipt.feed(lines: 1);
    }

    // Totals
    receipt.line();
    final subtotal = _items.fold<double>(
      0,
      (sum, item) => sum + (item['qty'] as int) * (item['price'] as double),
    );
    final tax = subtotal * 0.1;
    final total = subtotal + tax;

    receipt.row(left: 'Subtotal', right: '\$${subtotal.toStringAsFixed(2)}');
    receipt.row(left: 'Tax (10%)', right: '\$${tax.toStringAsFixed(2)}');
    receipt.doubleLine();
    receipt.bold().row(left: 'TOTAL', right: '\$${total.toStringAsFixed(2)}').normal();
    receipt.feed(lines: 1);

    // Payment
    receipt.text('Payment: Visa ****1234');
    receipt.feed(lines: 2);
    receipt.line();

    // Footer
    receipt
        .center()
        .text('Thank you for your purchase!')
        .feed(lines: 2)
        .text('Visit us again soon!')
        .feed(lines: 3)
        .cut();

    return receipt;
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final qtyController = TextEditingController(text: '1');
        final priceController = TextEditingController(text: '0.00');

        return AlertDialog(
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _items.add({
                    'name': nameController.text,
                    'qty': int.tryParse(qtyController.text) ?? 1,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _printReceipt() async {
    try {
      final receipt = _buildReceipt();
      await ThunderThermalPrint.printReceipt(receipt);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt printed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Builder Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: 'Add item',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _storeNameController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item['name'] as String),
                  subtitle: Text(
                    '${item['qty']} x \$${item['price']} = \$${((item['qty'] as int) * (item['price'] as double)).toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeItem(index),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _printReceipt,
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
            ),
          ),
        ],
      ),
    );
  }
}
