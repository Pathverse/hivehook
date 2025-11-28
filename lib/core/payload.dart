class HHPayloadI {
  const HHPayloadI();

  bool get isMutable => this is HHPayload;
}

class HHPayload extends HHPayloadI {
  final String? env;
  final String? key;
  final dynamic value;
  final Map<String, dynamic>? metadata;

  HHPayload({this.env, this.key, this.value, Map<String, dynamic>? metadata})
    : metadata = Map.unmodifiable(metadata ?? {});

  HHPayload copyWith({
    String? env,
    String? key,
    dynamic value,
    Map<String, dynamic>? metadata,
  }) {
    final newMetadata = metadata != null
        ? {...?this.metadata, ...metadata}
        : this.metadata;

    return HHPayload(
      key: key ?? this.key,
      value: value ?? this.value,
      metadata: newMetadata!,
    );
  }
}

class HHImmutablePayload extends HHPayloadI {
  final String? env;
  final String? key;
  final dynamic value;
  final Map<String, dynamic>? metadata;

  const HHImmutablePayload({
    this.env,
    this.key,
    this.value,
    required this.metadata,
  });

  HHImmutablePayload fromMutable(HHPayload payload) {
    return HHImmutablePayload(
      env: payload.env,
      key: payload.key,
      value: payload.value,
      metadata: payload.metadata,
    );
  }

  HHImmutablePayload copyWith({
    String? env,
    String? key,
    dynamic value,
    Map<String, dynamic>? metadata,
  }) {
    final newMetadata = metadata != null
        ? {...?this.metadata, ...metadata}
        : this.metadata;

    return HHImmutablePayload(
      key: key ?? this.key,
      value: value ?? this.value,
      metadata: newMetadata!,
    );
  }
}

extension HHPayloadExtensions on HHPayloadI {
  HHPayload asMutable() {
    if (this is HHPayload) {
      return this as HHPayload;
    } else if (this is HHImmutablePayload) {
      final immutable = this as HHImmutablePayload;
      return HHPayload(
        env: immutable.env,
        key: immutable.key,
        value: immutable.value,
        metadata: immutable.metadata,
      );
    } else {
      throw Exception('Unknown HHPayloadI implementation');
    }
  }

  HHImmutablePayload asImmutable() {
    if (this is HHImmutablePayload) {
      return this as HHImmutablePayload;
    } else if (this is HHPayload) {
      final mutable = this as HHPayload;
      return HHImmutablePayload(
        env: mutable.env,
        key: mutable.key,
        value: mutable.value,
        metadata: mutable.metadata,
      );
    } else {
      throw Exception('Unknown HHPayloadI implementation');
    }
  }
}
