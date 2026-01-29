import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

class EcommerceOrderScenario extends Scenario {
  @override
  String get name => 'E-Commerce Order';

  @override
  String get description =>
      'Complex nested order with customer, items, and payment';

  @override
  IconData get icon => Icons.shopping_cart;

  @override
  List<String> get tags => ['nested', 'metadata', 'real-world'];

  @override
  Future<void> run(LogCallback log) async {
    final hive = await HHive.create('demo');

    // Create complex order
    final order = <String, dynamic>{
      'orderId': 'ORD-2026-${DateTime.now().millisecondsSinceEpoch}',
      'customer': <String, dynamic>{
        'id': 'CUST-12345',
        'name': 'Jane Smith',
        'email': 'jane.smith@example.com',
        'tier': 'premium',
        'addresses': <String, dynamic>{
          'billing': <String, dynamic>{
            'street': '123 Oak Avenue',
            'apt': 'Suite 456',
            'city': 'San Francisco',
            'state': 'CA',
            'zip': '94102',
            'country': 'USA',
            'verified': true,
          },
          'shipping': <String, dynamic>{
            'street': '789 Pine Street',
            'apt': null,
            'city': 'Oakland',
            'state': 'CA',
            'zip': '94612',
            'country': 'USA',
            'verified': false,
            'instructions': 'Leave at door, ring doorbell twice',
          },
        },
        'preferences': <String, dynamic>{
          'marketing': false,
          'notifications': <String, dynamic>{
            'email': true,
            'sms': true,
            'push': false,
          },
        },
      },
      'items': <Map<String, dynamic>>[
        {
          'sku': 'LAPTOP-PRO-15',
          'name': 'ProBook Laptop 15"',
          'quantity': 1,
          'unitPrice': 1299.99,
          'options': {'ram': '32GB', 'storage': '1TB SSD', 'color': 'Space Gray'},
          'warranty': {
            'type': 'extended',
            'years': 3,
            'coverage': ['accidental', 'theft', 'hardware'],
          },
          'discount': {'type': 'percentage', 'value': 15, 'reason': 'premium_member'},
        },
        {
          'sku': 'MOUSE-WIRELESS',
          'name': 'ErgoMouse Wireless',
          'quantity': 2,
          'unitPrice': 79.99,
          'options': {'color': 'Black', 'dpi': 16000},
          'warranty': null,
          'discount': null,
        },
        {
          'sku': 'USB-C-HUB',
          'name': '7-in-1 USB-C Hub',
          'quantity': 1,
          'unitPrice': 89.99,
          'options': {
            'ports': ['HDMI', 'USB-A x3', 'SD', 'microSD', 'USB-C PD']
          },
          'warranty': {'type': 'standard', 'years': 1, 'coverage': ['hardware']},
          'discount': {'type': 'fixed', 'value': 10.00, 'reason': 'bundle'},
        },
      ],
      'totals': <String, dynamic>{
        'subtotal': 1549.96,
        'itemDiscounts': 204.99,
        'tax': {'rate': 0.0875, 'amount': 117.68},
        'shipping': {'method': 'express', 'cost': 14.99, 'estimatedDays': 2},
        'total': 1477.64,
        'currency': 'USD',
      },
      'payment': <String, dynamic>{
        'method': 'credit_card',
        'processor': 'stripe',
        'details': {'brand': 'visa', 'last4': '4242', 'expMonth': 12, 'expYear': 2027},
        'status': 'captured',
        'transactionId': 'pi_3N2xK2L...',
      },
      'fulfillment': <String, dynamic>{
        'status': 'processing',
        'carrier': null,
        'trackingNumber': null,
        'history': <Map<String, dynamic>>[
          {
            'status': 'created',
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
          },
          {
            'status': 'payment_captured',
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
          {
            'status': 'processing',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      },
      'notes': <Map<String, dynamic>>[
        {
          'type': 'customer',
          'text': 'Please gift wrap the laptop',
          'timestamp': DateTime.now()
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
        },
      ],
    };

    final customer = order['customer'] as Map<String, dynamic>;
    log('Creating order: ${order['orderId']}');
    log('Customer: ${customer['name']} (${customer['tier']})', level: LogLevel.data);

    final items = order['items'] as List<Map<String, dynamic>>;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      log('  Item ${i + 1}: ${item['name']} x${item['quantity']} @ \$${item['unitPrice']}',
          level: LogLevel.data);
    }

    final totals = order['totals'] as Map<String, dynamic>;
    log('Total: \$${totals['total']}', level: LogLevel.data);

    // Store with metadata
    await hive.put(
      'orders/${order['orderId']}',
      order,
      meta: {
        'version': 1,
        'source': 'web_demo',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    log('✓ Order stored with metadata', level: LogLevel.success);

    // Read back and verify
    final record = await hive.getWithMeta('orders/${order['orderId']}');
    log('Reading order back...');

    final retrieved = record.value as Map<String, dynamic>;
    log('Order ID: ${retrieved['orderId']}', level: LogLevel.data);
    log('Customer addresses:', level: LogLevel.info);

    final retCustomer = retrieved['customer'] as Map<String, dynamic>;
    final addresses = retCustomer['addresses'] as Map<String, dynamic>;
    final billing = addresses['billing'] as Map<String, dynamic>;
    final shipping = addresses['shipping'] as Map<String, dynamic>;
    log('  Billing: ${billing['city']}', level: LogLevel.data);
    log('  Shipping: ${shipping['city']}', level: LogLevel.data);

    log('Warranty coverage for laptop:', level: LogLevel.info);
    final retItems = retrieved['items'] as List;
    final laptop = retItems[0] as Map<String, dynamic>;
    final warranty = laptop['warranty'] as Map<String, dynamic>;
    final coverage = warranty['coverage'] as List;
    log('  ${coverage.join(', ')}', level: LogLevel.data);

    log('Fulfillment history:', level: LogLevel.info);
    final fulfillment = retrieved['fulfillment'] as Map<String, dynamic>;
    final history = fulfillment['history'] as List;
    for (final event in history) {
      final e = event as Map<String, dynamic>;
      final time = DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int);
      log('  ${e['status']} at ${time.toIso8601String()}', level: LogLevel.data);
    }

    log('Metadata:', level: LogLevel.info);
    const encoder = JsonEncoder.withIndent('  ');
    log('  ${encoder.convert(record.meta)}', level: LogLevel.data);

    // Verify deep equality
    final originalJson = jsonEncode(order);
    final retrievedJson = jsonEncode(retrieved);
    if (originalJson == retrievedJson) {
      log('✓ Deep equality verified', level: LogLevel.success);
    } else {
      log('✗ Data mismatch!', level: LogLevel.error);
    }
  }
}
