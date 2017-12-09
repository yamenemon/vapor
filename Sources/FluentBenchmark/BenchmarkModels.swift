import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        // create
        let a = Foo<Database>(bar: "asdf", baz: 42)
        let b = Foo<Database>(bar: "asdf", baz: 42)
        
        return a.save(on: conn).then { () -> Future<Void> in
            return b.save(on: conn)
        }.then { _ -> Future<Int> in
            return conn.query(Foo<Database>.self).count()
        }.then { count -> Future<Void> in
            if count != 2 {
                self.fail("count should have been 2")
            }
            
            // update
            b.bar = "fdsa"
            
            return b.save(on: conn)
        }.then { _ -> Future<Foo<Database>?> in
            return try Foo<Database>.find(b.requireID(), on: conn)
        }.then { fetched -> Future<Void> in
            // read
            if fetched?.bar != "fdsa" {
                self.fail("b.bar should have been updated")
            }
            
            return b.delete(on: conn)
        }.then { _ -> Future<Int> in
            return conn.query(Foo<Database>.self).count()
        }.map { count in
            if count != 1 {
                self.fail("count should have been 1")
            }
        }
    }

    /// Benchmark the basic model CRUD.
    public func benchmarkModels() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return try self._benchmark(on: conn).map {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the basic model CRUD.
    /// The schema will be prepared first.
    public func benchmarkModels_withSchema() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return FooMigration<Database>.prepare(on: conn).then {
                return try self._benchmark(on: conn).map {
                    self.pool.releaseConnection(conn)
                }
            }
        }
    }
}