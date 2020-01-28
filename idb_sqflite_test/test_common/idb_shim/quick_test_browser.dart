library all_test_browser;

import 'dart:async';

import 'package:idb_shim/idb_client_native.dart';

import 'idb_test_common.dart';
import 'multiplatform/exception_test.dart' as exception_test;
import 'multiplatform/index_test.dart' as index_test;
import 'multiplatform/simple_provider_test.dart' as simple_provider_test;
import 'multiplatform/transaction_test.dart' as transaction_test;

void testMain(TestContext ctx) {
  simple_provider_test.defineTests(ctx);
  index_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
  exception_test.defineTests(ctx);
}

void main() {
  group('native', () {
    if (idbFactoryNative != null) {
      final idbFactory = idbFactoryNative;
      final ctx = TestContext()..factory = idbFactory;
      testMain(ctx);
    } else {
      test('not supported', () {
        return Future.error('not supported');
      });
    }
  });

  group('memory', () {
    testMain(idbMemoryContext);
  });
}
