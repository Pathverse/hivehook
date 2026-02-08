import 'package:test/test.dart';
import 'package:hivehook/src/core/box_collection_config.dart';

void main() {
  group('BoxCollectionConfig', () {
    group('constructor', () {
      test('creates with required name', () {
        final config = BoxCollectionConfig(name: 'myapp');

        expect(config.name, 'myapp');
        expect(config.storagePath, isNull);
        expect(config.encryptionCipher, isNull);
        expect(config.boxNames, isEmpty);
        expect(config.includeMeta, isNull);
        expect(config.isExplicit, isTrue);
      });

      test('creates with all optional parameters', () {
        final config = BoxCollectionConfig(
          name: 'myapp',
          storagePath: '/custom/path',
          boxNames: {'users', 'settings'},
          includeMeta: true,
        );

        expect(config.name, 'myapp');
        expect(config.storagePath, '/custom/path');
        expect(config.boxNames, {'users', 'settings'});
        expect(config.includeMeta, isTrue);
      });
    });

    group('defaults factory', () {
      test('creates auto-config with isExplicit=false', () {
        final config = BoxCollectionConfig.defaults('myapp');

        expect(config.name, 'myapp');
        expect(config.storagePath, isNull);
        expect(config.encryptionCipher, isNull);
        expect(config.boxNames, isEmpty);
        expect(config.includeMeta, isNull);
        expect(config.isExplicit, isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated values', () {
        final original = BoxCollectionConfig(
          name: 'myapp',
          storagePath: '/original',
          boxNames: {'box1'},
          includeMeta: false,
        );

        final updated = original.copyWith(
          storagePath: '/updated',
          boxNames: {'box1', 'box2'},
        );

        expect(updated.name, 'myapp');
        expect(updated.storagePath, '/updated');
        expect(updated.boxNames, {'box1', 'box2'});
        expect(updated.includeMeta, isFalse);
      });

      test('preserves unchanged values', () {
        final original = BoxCollectionConfig(
          name: 'myapp',
          storagePath: '/path',
          includeMeta: true,
        );

        final updated = original.copyWith(name: 'newname');

        expect(updated.name, 'newname');
        expect(updated.storagePath, '/path');
        expect(updated.includeMeta, isTrue);
      });
    });

    group('validate', () {
      test('passes for valid config', () {
        final config = BoxCollectionConfig(name: 'myapp');
        expect(() => config.validate(), returnsNormally);
      });

      test('throws on empty name', () {
        final config = BoxCollectionConfig(name: '');
        expect(
          () => config.validate(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('name cannot be empty'),
          )),
        );
      });
    });

    group('shouldIncludeMeta', () {
      test('returns true when includeMeta=true regardless of hasMetaConfig', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: true);

        expect(config.shouldIncludeMeta(false), isTrue);
        expect(config.shouldIncludeMeta(true), isTrue);
      });

      test('returns false when includeMeta=false regardless of hasMetaConfig', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: false);

        expect(config.shouldIncludeMeta(false), isFalse);
        expect(config.shouldIncludeMeta(true), isFalse);
      });

      test('returns hasMetaConfig when includeMeta=null (auto-detect)', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: null);

        expect(config.shouldIncludeMeta(false), isFalse);
        expect(config.shouldIncludeMeta(true), isTrue);
      });
    });

    group('validateMetaRequirement', () {
      test('passes when includeMeta=true and meta required', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: true);
        expect(() => config.validateMetaRequirement(true), returnsNormally);
      });

      test('passes when includeMeta=null and meta required', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: null);
        expect(() => config.validateMetaRequirement(true), returnsNormally);
      });

      test('passes when includeMeta=false and meta not required', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: false);
        expect(() => config.validateMetaRequirement(false), returnsNormally);
      });

      test('throws when includeMeta=false but meta required', () {
        final config = BoxCollectionConfig(name: 'myapp', includeMeta: false);
        
        expect(
          () => config.validateMetaRequirement(true),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('includeMeta=false'),
          )),
        );
      });
    });
  });
}
