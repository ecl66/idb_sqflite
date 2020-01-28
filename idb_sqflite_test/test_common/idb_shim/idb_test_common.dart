library idb_shim.idb_test_common;

import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:dev_test/test.dart' as dev_test;
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/src/sembast_fs.dart' as sdb_fs;

import 'multiplatform/common_meta_test.dart';

export 'dart:async';

export 'package:dev_test/test.dart';
export 'package:idb_shim/idb_client_memory.dart';
export 'package:idb_shim/src/common/common_meta.dart';
export 'package:idb_shim/src/utils/dev_utils.dart';

//import 'package:unittest/unittest.dart';
//export 'common_meta_test.dart' hide main;
//export 'package:tekartik_test/test_utils.dart';

// only for test - INFO - basic output, FINE - show test name before/after - FINEST - samething for console test also
const Level debugLevel = Level.FINE;
@deprecated
const String testDbName = 'test.db';
const String _testDbName = 'test.db';
const String testStoreName = 'test_store';
const String testStoreName2 = 'test_store_2';

const String testNameIndex = 'name_index';
const String testNameField = 'name';
const String testValueIndex = 'value_index';
const String testValueField = 'value';

const String testNameIndex2 = 'name_index_2';
const String testNameField2 = 'name_2';

// current dbName valid during test execution
String dbTestName;
// current dbContext
TestContext _dbTestContext;

void dbGroup(TestContext ctx, String description, body, [_group = group]) {
  _group(description, () {
    _dbTestContext = ctx;
    body();
    _dbTestContext = null;
  });
}

void dbTest(String description, body,
    {void Function(String name, Function() body, {bool solo}) test,
    @deprecated bool solo}) {
  test ??= dev_test.test;
  // We save it for later
  // only valid during definition
  final ctx = _dbTestContext;
  test(description, () async {
    dbTestName = ctx.dbName;
    await ctx.factory.deleteDatabase(dbTestName);
    await Future.value(body());
  }, solo: solo == true);
}

class TestContext {
  IdbFactory factory;

  String get dbName => testDescriptions.join('-') + '.db';

  // special internet explorer handling
  bool isIdbIe = false;
  bool isIdbEdge = false;
  bool isIdbSafari = false;
  bool isIdbSembast = false;

  // ie don't except any pause between 2 calls
  bool get isIdbNoLazy => isIdbSembast || isIdbIe;

  bool get isInMemory => false;

  /// true if double can be used as key
  bool get supportsDoubleKey => (factory as IdbFactoryBase).supportsDoubleKey;
}

class SembastTestContext extends TestContext {
  @override
  bool get isIdbSembast => true;

  sdb.DatabaseFactory sdbFactory;

  @override
  IdbFactorySembast get factory => super.factory as IdbFactorySembast;

  @override
  String get dbName => join(joinAll(testDescriptions), 'test.db');
}

class SembastMemoryTestContext extends SembastTestContext {
  SembastMemoryTestContext() {
    factory = idbFactoryMemory;
  }

  @override
  bool get isInMemory => true;
}

TestContext idbMemoryContext = SembastMemoryTestContext();

class SembastFsTestContext extends SembastTestContext {
  @override
  sdb_fs.DatabaseFactoryFs get sdbFactory =>
      factory.sdbFactory as sdb_fs.DatabaseFactoryFs;

  @override
  IdbFactorySembast get factory => super.factory;
}

class SembastMemoryFsTestContext extends SembastFsTestContext {
  SembastMemoryFsTestContext() {
    factory = idbFactoryMemoryFs;
  }

  // It is actually not considerd in memory in our tests
  @override
  bool get isInMemory => false;
}

SembastFsTestContext idbMemoryFsContext = SembastMemoryFsTestContext();

IdbFactory idbTestMemoryFactory = idbFactoryMemory;

Future<Database> setUpSimpleStore(IdbFactory idbFactory, //
    {String dbName = _testDbName,
    IdbObjectStoreMeta meta}) {
  meta ??= idbSimpleObjectStoreMeta;

  return idbFactory.deleteDatabase(dbName).then((_) {
    void _initializeDatabase(VersionChangeEvent e) {
      final db = e.database;
      final objectStore = db.createObjectStore(meta.name,
          keyPath: meta.keyPath, autoIncrement: meta.autoIncrement);
      for (final indexMeta in meta.indecies) {
        objectStore.createIndex(indexMeta.name, indexMeta.keyPath,
            unique: indexMeta.unique, multiEntry: indexMeta.multiEntry);
      }
    }

    return idbFactory.open(dbName,
        version: 1, onUpgradeNeeded: _initializeDatabase);
  });
}

bool isDatabaseError(e) {
  return (e is DatabaseError);
}

bool isTransactionReadOnlyError(e) {
  // if (e is DatabaseError) {
  final message = e.toString().toLowerCase();
  if (message.contains('readonly')) {
    return true;
  }
  if (message.contains('read_only')) {
    return true;
  }

  return false;
}

bool isTransactionInactiveError(e) {
  // if (e is DatabaseError) {
  final message = e.toString().toLowerCase();
  if (message.contains('inactive')) {
    return true;
  }
  //}
  return false;
}

bool isNotFoundError(e) {
  //if (e is DatabaseError) {
  final message = e.toString().toLowerCase();
  if (message.contains('notfounderror')) {
    return true;
  }
  //}
  return false;
}

bool isTestFailure(e) {
  return e is TestFailure;
}
