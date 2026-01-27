/// Sample complex data types for testing HiveHook serialization

class User {
  final String id;
  final String name;
  final String email;
  final int age;
  final List<String> roles;
  final DateTime createdAt;
  final Address? address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    this.roles = const [],
    DateTime? createdAt,
    this.address,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'age': age,
        'roles': roles,
        'createdAt': createdAt.toIso8601String(),
        'address': address?.toJson(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        age: json['age'] as int,
        roles: List<String>.from(json['roles'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        address: json['address'] != null
            ? Address.fromJson(json['address'] as Map<String, dynamic>)
            : null,
      );

  @override
  String toString() => 'User($name, $email)';
}

class Address {
  final String street;
  final String city;
  final String country;
  final String? zipCode;

  Address({
    required this.street,
    required this.city,
    required this.country,
    this.zipCode,
  });

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'country': country,
        'zipCode': zipCode,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        zipCode: json['zipCode'] as String?,
      );

  @override
  String toString() => '$street, $city, $country';
}

class Product {
  final String sku;
  final String name;
  final double price;
  final int quantity;
  final List<String> tags;
  final Map<String, dynamic> attributes;

  Product({
    required this.sku,
    required this.name,
    required this.price,
    this.quantity = 0,
    this.tags = const [],
    this.attributes = const {},
  });

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'price': price,
        'quantity': quantity,
        'tags': tags,
        'attributes': attributes,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        sku: json['sku'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int? ?? 0,
        tags: List<String>.from(json['tags'] ?? []),
        attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
      );

  @override
  String toString() => 'Product($name, \$$price)';
}

class Session {
  final String token;
  final String userId;
  final DateTime expiresAt;
  final Map<String, dynamic> permissions;

  Session({
    required this.token,
    required this.userId,
    required this.expiresAt,
    this.permissions = const {},
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'expiresAt': expiresAt.toIso8601String(),
        'permissions': permissions,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        userId: json['userId'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        permissions: Map<String, dynamic>.from(json['permissions'] ?? {}),
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  String toString() => 'Session(user: $userId, expired: $isExpired)';
}

/// Sample data generators
class SampleData {
  static User sampleUser({String? id}) => User(
        id: id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: 'John Doe',
        email: 'john@example.com',
        age: 30,
        roles: ['admin', 'user'],
        address: Address(
          street: '123 Main St',
          city: 'San Francisco',
          country: 'USA',
          zipCode: '94102',
        ),
      );

  static Product sampleProduct({String? sku}) => Product(
        sku: sku ?? 'SKU_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Widget Pro',
        price: 99.99,
        quantity: 100,
        tags: ['electronics', 'gadgets', 'new'],
        attributes: {
          'color': 'blue',
          'weight': 0.5,
          'dimensions': {'w': 10, 'h': 5, 'd': 2},
        },
      );

  static Session sampleSession({int ttlSeconds = 3600}) => Session(
        token: 'tok_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user_123',
        expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
        permissions: {
          'read': true,
          'write': true,
          'admin': false,
        },
      );
}
