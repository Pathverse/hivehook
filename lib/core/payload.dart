class HHPayload {
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

class HHImmutablePayload {
  final String? env;
  final String? key;
  final dynamic value;
  final Map<String, dynamic>? metadata;

  const HHImmutablePayload({this.env, this.key, this.value, required this.metadata});

  HHImmutablePayload fromMutable(HHPayload payload) {
    return HHImmutablePayload(
      env: payload.env,
      key: payload.key,
      value: payload.value,
      metadata: payload.metadata,
    );
  }
}
