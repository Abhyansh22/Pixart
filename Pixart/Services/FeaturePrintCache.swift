//
//  FeaturePrintCache.swift
//  Pixart
//

import Foundation
import Vision
import SQLite3

/// Thread-safe SQLite cache for Vision VNFeaturePrintObservation data.
actor FeaturePrintCache {
    static let shared = FeaturePrintCache()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let path = appSupport.appendingPathComponent("feature_prints_v1.sqlite").path
        self.dbPath = path
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func ensureDatabaseOpen() {
        guard db == nil else { return }
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            createTable()
        } else {
            print("[FeaturePrintCache] Failed to open database at \(dbPath)")
        }
    }
    
    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS feature_prints (
            local_identifier TEXT PRIMARY KEY,
            feature_data BLOB NOT NULL,
            aspect_band INTEGER NOT NULL,
            week_bucket INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_bucket ON feature_prints (aspect_band, week_bucket);
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("[FeaturePrintCache] Error creating table: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    /// Returns the set of all asset identifiers already present in the cache.
    func getAllCachedIdentifiers() -> Set<String> {
        ensureDatabaseOpen()
        var identifiers = Set<String>()
        let sql = "SELECT local_identifier FROM feature_prints;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(statement, 0) {
                    identifiers.insert(String(cString: cStr))
                }
            }
        }
        sqlite3_finalize(statement)
        return identifiers
    }
    
    /// Saves a batch of feature prints to the database inside a transaction.
    func saveBatch(items: [(id: String, observation: VNFeaturePrintObservation, aspectBand: Int, weekBucket: Int64)]) {
        ensureDatabaseOpen()
        guard !items.isEmpty else { return }
        
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        
        let sql = "INSERT OR REPLACE INTO feature_prints (local_identifier, feature_data, aspect_band, week_bucket) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for item in items {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: item.observation, requiringSecureCoding: true)
                    
                    sqlite3_bind_text(statement, 1, (item.id as NSString).utf8String, -1, nil)
                    data.withUnsafeBytes { rawBuffer in
                        sqlite3_bind_blob(statement, 2, rawBuffer.baseAddress, Int32(rawBuffer.count), nil)
                    }
                    sqlite3_bind_int(statement, 3, Int32(item.aspectBand))
                    sqlite3_bind_int64(statement, 4, item.weekBucket)
                    
                    if sqlite3_step(statement) != SQLITE_DONE {
                        print("[FeaturePrintCache] Failed to insert item \(item.id)")
                    }
                    sqlite3_reset(statement)
                } catch {
                    print("[FeaturePrintCache] Failed to archive observation: \(error)")
                }
            }
        }
        sqlite3_finalize(statement)
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }
    
    struct CachedPrint: @unchecked Sendable {
        let identifier: String
        let observation: VNFeaturePrintObservation
        let aspectBand: Int
        let weekBucket: Int64
    }
    
    /// Loads all cached feature prints.
    func loadAll() -> [CachedPrint] {
        ensureDatabaseOpen()
        var results = [CachedPrint]()
        let sql = "SELECT local_identifier, feature_data, aspect_band, week_bucket FROM feature_prints;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(statement, 0),
                      let blobBytes = sqlite3_column_blob(statement, 1) else {
                    continue
                }
                let blobCount = sqlite3_column_bytes(statement, 1)
                let id = String(cString: idCStr)
                let aspectBand = Int(sqlite3_column_int(statement, 2))
                let weekBucket = sqlite3_column_int64(statement, 3)
                let data = Data(bytes: blobBytes, count: Int(blobCount))
                
                if let observation = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
                    results.append(CachedPrint(
                        identifier: id,
                        observation: observation,
                        aspectBand: aspectBand,
                        weekBucket: weekBucket
                    ))
                }
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    /// Removes specified identifiers from the cache (e.g. when deleted from library).
    func remove(identifiers: [String]) {
        ensureDatabaseOpen()
        guard !identifiers.isEmpty else { return }
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        let sql = "DELETE FROM feature_prints WHERE local_identifier = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for id in identifiers {
                sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
                sqlite3_reset(statement)
            }
        }
        sqlite3_finalize(statement)
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }
}
