library object_store_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';

import '../idb_test_common.dart';
import 'common_meta_test.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  Database db;
  Transaction transaction;
  ObjectStore objectStore;

  void _createTransaction() {
    transaction = db.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction.objectStore(testStoreName);
  }

  // new
  String _dbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _dbName = ctx.dbName;
    await idbFactory.deleteDatabase(_dbName);
  }

  // generic tearDown
  Future _tearDown() async {
    if (transaction != null) {
      await transaction.completed;
      transaction = null;
    }
    if (db != null) {
      db.close();
      db = null;
    }
  }

  group('object_store', () {
    // Make testDbName less bad
    final testDbName = ctx.dbName;

    group('failure', () {
      setUp(() async {
        await idbFactory.deleteDatabase(testDbName);
      });

      test('create object store not in initialize', () {
        return idbFactory.open(testDbName).then((Database database) {
          try {
            database.createObjectStore(testStoreName, autoIncrement: true);
          } catch (e) {
            //print(e.runtimeType);
            database.close();
            return;
          }
          fail('should fail');
        });
      });
    });

    group('init', () {
      tearDown(_tearDown);

      try {
        test('delete', () async {
          await _setupDeleteDb();

          void _createStore(VersionChangeEvent e) {
            final db = e.database;
            db.createObjectStore(testStoreName);
          }

          var db = await idbFactory.open(_dbName,
              version: 1, onUpgradeNeeded: _createStore);
          var txn = db.transaction(testStoreName, idbModeReadWrite);
          var store = txn.objectStore(testStoreName);
          await store.put('value', 'key');
          expect(await store.getObject('key'), 'value');
          await txn.completed;

          db.close();

          // this does not work for in memory database..
          if (!ctx.isInMemory) {
            void _deleteAndCreateStore(VersionChangeEvent e) {
              final db = e.database;
              db.deleteObjectStore(testStoreName);
              db.createObjectStore(testStoreName);
            }

            db = await idbFactory.open(_dbName,
                version: 2, onUpgradeNeeded: _deleteAndCreateStore);
            txn = db.transaction(testStoreName, idbModeReadOnly);
            store = txn.objectStore(testStoreName);
            expect(await store.getObject('key'), null);
            await txn.completed;
            db.close();
          }
        });
      } catch (e, s) {
        print(s);
      }
    });

    group('non_auto', () {
      tearDown(_tearDown);

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, null);
        expect(objectStore.name, testStoreName);
        expect(objectStore.indexNames, []);

        // ie weird missing feature
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, false);
        }
      });

      test('add/get map', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((readValue) {
            expect(readValue, value);
          });
        });
      });

      // not working in js firefox
      test('add_twice_same_key', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return transaction.completed.then((_) {
            _createTransaction();
            return objectStore.add(value, 123).then((_) {}, onError: (e) {
              transaction = null;
            }).then((_) {
              expect(transaction, null);
            });
          });
        });
      });

      test('add/get string', () async {
        await _setUp();
        _createTransaction();
        final value = '4567';
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((readValue) {
            expect(readValue, value);
          });
        });
      });

      test('getObject_null', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(null);
          fail('error');
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(e, isNotNull);
        }
      });

      test('getObject_boolean', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(true);
          fail('error');
        } catch (e) {
          expect(isTestFailure(e), isFalse);
          expect(e, isNotNull);
        }
      });

      test('put/get_key_double', () async {
        if (ctx.supportsDoubleKey) {
          await _setUp();
          _createTransaction();
          final value = 'test';
          expect(await objectStore.getObject(1.2), isNull);
          final key = 0.001;
          final keyAdded = await objectStore.add(value, key) as double;
          expect(keyAdded, key);
          expect(await objectStore.getObject(key), value);
        }
      });
    });

    group('auto', () {
      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, null);
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, true);
        }
      }, testOn: '!ie');

      // Good first test
      test('add', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        });
      });

      test('add2', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 2);
          });
        });
      });

      test('add with key and next', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value).then((key) {
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 1235);
            }
          });
        });
      });

      // limitation, this crashes everywhere
      test('add_with_same_key', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        final key = await objectStore.add(value, 1234) as int;
        expect(key, 1234);
        try {
          await objectStore.add(value, 1234);
          fail('should fail');
        } on DatabaseError catch (e) {
          expect(isTestFailure(e), isFalse);
        }
        // cancel transaction
        transaction = null;
      });

      test('add with key then back', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value, 1232).then((key) {
            expect(key, 1232);
          });
        }).then((_) {
          return objectStore.add(value).then((key) {
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 1235);
            }
          });
        });
      });

      // limitation
      // websql make it 3 while idb and sembast make it one...
      test('add_with_text_number_key_and_next', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        final key2 = await objectStore.add(value, '2') as String;
        expect(key2, '2');
        final key1 = await objectStore.add(value) as int;
        expect(key1 == 1 || key1 == 3, isTrue);
      });

      // limitation
      // Sql does not support text and auto increment
      test('add_with_text_key_and_next', () async {
        await _setUp();
        _createTransaction();
        final value1 = {'test': 1};
        final value2 = {'test': 2};
        final keyTest = await objectStore.add(value1, 'test') as String;
        expect(keyTest, 'test');
        final key1 = await objectStore.add(value2) as int;
        expect(key1, 1);

        var valueRead = await objectStore.getObject(1) as Map;
        valueRead = await objectStore.getObject('test') as Map;
        expect(valueRead, value1);
      }, skip: true);

      test('get', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((value) {
            expect(value.length, 0);
          });
        });
      });

      test('simple get', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('get dummy', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key + 1).then((value) {
            expect(value, null);
          });
        });
      });

      test('get none', () async {
        await _setUp();
        _createTransaction();
        //Map value = {};
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('count_one', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        await objectStore.add(value);

        // crashes on ie
        if (!ctx.isIdbIe) {
          expect(await objectStore.count(), 1);
        }
      });

      test('count by key', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore.count(key1).then((int count) {
              expect(count, 1);
              return objectStore.count(key2).then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('count by range', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore
                .count(KeyRange.lowerBound(key1, true))
                .then((int count) {
              expect(count, 1);
              return objectStore
                  .count(KeyRange.lowerBound(key1))
                  .then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('count_empty', () async {
        // count() crashes on ie
        if (!ctx.isIdbIe) {
          await _setUp();
          _createTransaction();
          return objectStore.count().then((int count) {
            expect(count, 0);
          });
        }
      });

      test('delete', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          return objectStore.delete(key).then((_) {
            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('delete empty', () async {
        await _setUp();
        _createTransaction();
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('delete dummy', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.delete(key + 1).then((deleteResult) {
            // check fist one still here
            return objectStore.getObject(key).then((valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('simple update', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
            value['test'] = 'new_value';
            return objectStore.put(value, key).then((putResult) {
              expect(putResult, key);
              return objectStore.getObject(key).then((valueRead2) {
                expect(valueRead2, value);
                expect(valueRead2, isNot(equals(valueRead)));
              });
            });
          });
        });
      });

      test('update empty', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.put(value, 1234).then((value) {
          expect(value, 1234);
        });
      });

      test('update dummy', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          final newValue = cloneValue(value) as Map;
          newValue['test'] = 'new_value';
          return objectStore.put(newValue, key + 1).then((deleteResult) {
            // check fist one still here
            return objectStore.getObject(key).then((valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('clear', () async {
        await _setUp();
        _createTransaction();
        final value = {};
        return objectStore.add(value).then((key) {
          return objectStore.clear().then((clearResult) {
            expect(clearResult, null);

            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('clear empty', () async {
        await _setUp();
        _createTransaction();
        return objectStore.clear().then((clearResult) {
          expect(clearResult, null);
        });
      });
    });

    // skipped for firefox
    group('readonly', () {
      void _createTransaction() {
        transaction = db.transaction(testStoreName, idbModeReadOnly);
        objectStore = transaction.objectStore(testStoreName);
      }

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('add', () async {
        await _setUp();
        _createTransaction();
        return objectStore.add({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('put', () async {
        await _setUp();
        _createTransaction();
        return objectStore.put({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('clear', () async {
        await _setUp();
        _createTransaction();
        return objectStore.clear().catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });

      test('delete', () async {
        await _setUp();
        _createTransaction();
        return objectStore.delete(1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTestFailure(e), isFalse);
          expect(isTransactionReadOnlyError(e), isTrue);
          // don't wait for transaction
          transaction = null;
        });
      });
    });

    group('key_path_auto', () {
      const keyPath = 'my_key';

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName,
              keyPath: keyPath, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, keyPath);

        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, true);
        }
      });

      test('simple get', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 1);
          return objectStore.getObject(key).then((valueRead) {
            final expectedValue = cloneValue(value) as Map;
            expectedValue[keyPath] = 1;
            expect(valueRead, expectedValue);
          });
        });
      });

      test('simple add with keyPath and next', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value', keyPath: 123};
        return objectStore.add(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        }).then((_) {
          final value = {
            'test': 'test_value',
          };
          return objectStore.add(value).then((key) {
            // On Safari this is 1
            if (ctx.isIdbSafari) {
              expect(key, 1);
            } else {
              expect(key, 124);
            }
          });
        });
      });

      test('put with keyPath', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value', keyPath: 123};
        return objectStore.put(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('add key and keyPath', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value', keyPath: 123};
        return objectStore.add(value, 123).then((_) {
          fail('should fail');
        }, onError: (e, st) {
          // 'both key 123 and inline keyPath 123 are specified
          //devPrint(e);
          // mark transaction as null
          transaction = null;
        });
      });

      test('put key and keyPath', () async {
        await _setUp();
        _createTransaction();
        final value = {'test': 'test_value', keyPath: 123};
        return objectStore.put(value, 123).then((_) {
          fail('should fail');
        }, onError: (e) {
          //print(e);
          transaction = null;
        });
      });
    });

    group('key_path_non_auto', () {
      const keyPath = 'my_key';

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('properties', () async {
        await _setUp();
        _createTransaction();
        expect(objectStore.keyPath, keyPath);
        if (ctx.isIdbIe) {
          expect(objectStore.autoIncrement, isNull);
        } else {
          expect(objectStore.autoIncrement, false);
        }
      });

      test('simple add_without_key_path', () async {
        await _setUp();
        _createTransaction();
        final value = {'non_key_path': 'test_value'};
        try {
          await objectStore.add(value);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
        }
      });

      test('simple add_get', () async {
        await _setUp();
        _createTransaction();
        final value = {keyPath: 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('simple put_get', () async {
        await _setUp();
        _createTransaction();
        final value = {keyPath: 'test_value'};
        return objectStore.put(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('add_null', () async {
        await _setUp();
        _createTransaction();
        final value = {'dummy': 'test_value'};
        return objectStore.add(value).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          // IdbMemoryError(3): neither keyPath nor autoIncrement set and trying to add object without key
          expect(isTestFailure(e), isFalse);
          //expect(e is DatabaseError, isTrue);
          transaction = null;
        });
      });

      test('put_null', () async {
        await _setUp();
        _createTransaction();
        final value = {'dummy': 'test_value'};
        return objectStore.put(value).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          expect(isTestFailure(e), isFalse);
          //expect(e is DatabaseError, isTrue);
          transaction = null;
        });
      });

      test('add_twice', () async {
        await _setUp();
        _createTransaction();
        final value = {keyPath: 'test_value'};
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.add(value).catchError((e) {
            // There must be an error!
            return e;
          }).then((e) {
            //expect(isTransactionReadOnlyError(e), isTrue);
            //devPrint(e);
            // expect(e is DatabaseError, isTrue);
            expect(isTestFailure(e), isFalse);

            // in native completed will never succeed so remove it
            transaction = null;
          });
        });
      });

      // put twice should be fine
      test('put_twice', () async {
        await _setUp();
        _createTransaction();
        final value = {keyPath: 'test_value'};
        var key = await objectStore.put(value) as String;
        expect(key, 'test_value');
        key = await objectStore.put(value) as String;

        // There must be only one item
        expect(await objectStore.count(key), 1);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          expect(await objectStore.count(), 1);
        }
      });
    });

    // not working in memory since not persistent
    if (!ctx.isInMemory) {
      group('create store and re-open', () {
        setUp(() {
          return idbFactory.deleteDatabase(testDbName);
        });

        Future testStore(IdbObjectStoreMeta storeMeta) {
          return setUpSimpleStore(idbFactory,
                  meta: storeMeta, dbName: testDbName)
              .then((Database db) {
            db.close();
          }).then((_) async {
            final db = await idbFactory.open(testDbName);
            final transaction = db.transaction(storeMeta.name, idbModeReadOnly);
            final objectStore = transaction.objectStore(storeMeta.name);
            var readMeta = IdbObjectStoreMeta.fromObjectStore(objectStore);

            // ie idb does not have autoIncrement
            if (ctx.isIdbIe) {
              readMeta = IdbObjectStoreMeta(readMeta.name, readMeta.keyPath,
                  storeMeta.autoIncrement, readMeta.indecies.toList());
            }
            expect(readMeta, storeMeta);
            await transaction.completed;
            db.close();
          });
        }

        test('all', () {
          final iterator = idbObjectStoreMetas.iterator;

          Future _next() {
            if (iterator.moveNext()) {
              return testStore(iterator.current).then((_) {
                return _next();
              });
            }
            return Future.value();
          }

          return _next();
        });
      });
    }

    group('dotted_key_path_non_auto', () {
      const keyPath = 'my.key';

      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: keyPath);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('simple add_without_key_path', () async {
        await _setUp();
        _createTransaction();
        final value = {'non_key_path': 'test_value'};
        try {
          await objectStore.add(value);
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
        }
      });

      test('add_with_key_path', () async {
        await _setUp();
        _createTransaction();
        final value = {
          'my': {'key': 'test_value'}
        };
        await objectStore.add(value);
        expect(await objectStore.getObject('test_value'), value);
      });

      test('add_put_with_key', () async {
        await _setUp();
        _createTransaction();
        final value = {'dummy': 2};

        try {
          await objectStore.add(value, 'test_value');
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
          // Failed to execute 'add' on 'IDBObjectStore': The object store uses in-line keys and the key parameter was provided.
          // devPrint(_);
        }

        try {
          await objectStore.put(value, 'test_value');
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
          // Failed to execute 'add' on 'IDBObjectStore': The object store uses in-line keys and the key parameter was provided.
          // devPrint(_);
        }
      });

      test('put_with_key_and_key_path', () async {
        await _setUp();
        _createTransaction();
        final value = {
          'my': {'key': 'test_value'}
        };

        try {
          await objectStore.add(value, 'test_value');
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
          // Failed to execute 'add' on 'IDBObjectStore': The object store uses in-line keys and the key parameter was provided.
          // devPrint(_);
        }

        try {
          await objectStore.put(value, 'test_value');
          fail('should fail');
        } catch (e) {
          expect(e, isNot(const TypeMatcher<TestFailure>()));
          // Failed to execute 'add' on 'IDBObjectStore': The object store uses in-line keys and the key parameter was provided.
          // devPrint(_);
        }
        // expect(await objectStore.getObject('test_value'), result);
      });
    });

    group('various', () {
      Future _setUp() async {
        await _setupDeleteDb();
        db = await setUpSimpleStore(idbFactory, dbName: _dbName);
      }

      tearDown(_tearDown);

      test('delete', () async {
        await _setUp();
        _createTransaction();
        return objectStore.add('test').then((key) {
          return objectStore.delete(key).then((result) {
            expect(result, isNull);
          });
        });
      });
    });

    group('multi_store', () {
      Future _setUp() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
          db.createObjectStore(testStoreName2, autoIncrement: true);
        }

        db = await idbFactory.open(_dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
      }

      tearDown(_tearDown);

      test('simple add_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add('test_value1');
        expect(key1, 1);
        var objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add('test_value2');
        expect(key2, 1);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), 'test_value1');
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), 'test_value2');
      });

      test('simple add_put_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add('test_value1');
        expect(key1, 1);
        var objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add('test_value2');
        expect(key2, 1);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        objectStore1 = transaction.objectStore(testStoreName);
        await objectStore1.put('update_value1', key1);
        objectStore2 = transaction.objectStore(testStoreName2);
        await objectStore2.put('update_value2', key2);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), 'update_value1');
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), 'update_value2');
      });

      test('order_add_get', () async {
        await _setUp();
        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var objectStore1 = transaction.objectStore(testStoreName);
        var key1 = await objectStore1.add('test_value1');
        expect(key1, 1);
        objectStore1 = transaction.objectStore(testStoreName);
        var key1_1 = await objectStore1.add('test_value1_1');
        expect(key1_1, 2);
        var objectStore2 = transaction.objectStore(testStoreName2);
        var key2 = await objectStore2.add('test_value2');
        expect(key2, 1);
        objectStore1 = transaction.objectStore(testStoreName);
        var key1_2 = await objectStore1.add('test_value1_2');
        expect(key1_2, 3);
        await transaction.completed;

        transaction =
            db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
        objectStore1 = transaction.objectStore(testStoreName);
        expect(await objectStore1.getObject(key1), 'test_value1');
        expect(await objectStore1.getObject(key1_1), 'test_value1_1');
        expect(await objectStore1.getObject(key1_2), 'test_value1_2');
        objectStore2 = transaction.objectStore(testStoreName2);
        expect(await objectStore2.getObject(key2), 'test_value2');
      });
    });
  });
}
