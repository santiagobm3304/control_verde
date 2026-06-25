import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /* ===================== DB INIT ===================== */

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reporte.db');

    return await openDatabase(
      path,
      version: 7, // 🔥 SUBIMOS VERSIÓN
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /* ===================== CREATE ===================== */

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reporte (
        _id TEXT,
        ean TEXT,
        tim INTEGER,
        olpn TEXT,
        uMedida TEXT,
        subdpto TEXT,
        sku TEXT,
        descripcion TEXT,
        casePack INTEGER,
        precioVigente INTEGER,
        costoPromedio INTEGER,
        uEnviadas REAL,
        uRecibidas REAL,
        fechavencimiento TEXT,
        observacion TEXT,
        isContable INTEGER,
        marcaSensible INTEGER,
        modificadoPor TEXT,
        editadoPor TEXT,
        isLocked INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE producto (
        _id TEXT PRIMARY KEY NOT NULL,
        subdpto TEXT,
        proveedor TEXT,
        ean TEXT,
        sku TEXT,
        descripcion TEXT,
        marca TEXT,
        __v INTEGER,
        costoPromedio REAL,
        precioVigente REAL,
        casePack INTEGER,
        uMedida TEXT,
        detalle TEXT,
        createdAt TEXT,
        marcaSensible INTEGER,
        isContable INTEGER,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reporte_tim (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tim INTEGER,
        placa TEXT,
        localOrigen TEXT,
        localDestino TEXT,
        fechaEnvio TEXT,
        motivo TEXT,
        creadoPor TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        rol TEXT NOT NULL,
        token TEXT NOT NULL,
        dni TEXT,
        correo TEXT
      )
    ''');
  }

  /* ===================== UPGRADE ===================== */

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🚀 Actualizando DB de version $oldVersion a $newVersion');
    if (oldVersion < 7) {
      // 1. Asegurar app_user
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_user (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          rol TEXT NOT NULL,
          token TEXT NOT NULL,
          dni TEXT,
          correo TEXT
        )
      ''');

      // 2. Agregar campos faltantes a 'reporte'
      // Usamos TRY-CATCH individual para cada columna por si ya existen en algún cliente
      try {
        await db.execute("ALTER TABLE reporte ADD COLUMN editadoPor TEXT");
      } catch (e) {
        debugPrint('⚠️ Columna editadoPor ya existe o error: $e');
      }

      try {
        await db.execute("ALTER TABLE reporte ADD COLUMN isLocked INTEGER DEFAULT 0");
      } catch (e) {
        debugPrint('⚠️ Columna isLocked ya existe o error: $e');
      }
    }
  }

  /* ===================== TUS MÉTODOS (SIN CAMBIOS) ===================== */

  Future<List<Map<String, dynamic>>> searchByEan(String ean) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT reporte.*
      FROM producto
      INNER JOIN reporte ON producto.sku = reporte.sku
      WHERE producto.ean = ?
    ''', [ean]);
  }

  Future<void> insertReporteTim(ReporteTim reporteTim) async {
    final db = await instance.database;

    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM reporte_tim WHERE tim = ?',
        [reporteTim.tim],
      ),
    );

    if (result != null && result > 0) return;

    await db.insert(
      'reporte_tim',
      reporteTim.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<ReporteTim?> getReporteTimByTim(int numeroTim) async {
    final db = await instance.database;
    final maps = await db.query(
      'reporte_tim',
      where: 'tim = ?',
      whereArgs: [numeroTim],
    );
    return maps.isNotEmpty ? ReporteTim.fromMap(maps.first) : null;
  }

  Future<List<ReporteTim>> fetchReporteTim() async {
    final db = await instance.database;
    final maps = await db.query('reporte_tim');
    return maps.map((e) => ReporteTim.fromMap(e)).toList();
  }

  Future<void> insertProducto(Producto producto) async {
    final db = await instance.database;
    await db.insert(
      'producto',
      producto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Producto>> getProductos() async {
    final db = await instance.database;
    final maps = await db.query('producto');
    return maps.map((e) => Producto.fromMap(e)).toList();
  }

  Future<void> guardarProductosLocal(
    List<Map<String, dynamic>> productos,
  ) async {
    final db = await instance.database;
    final batch = db.batch();

    debugPrint('📦 Guardando ${productos.length} productos');

    for (final p in productos) {
      batch.insert(
        'producto',
        p,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM producto'),
    );

    debugPrint('✅ Total productos en SQLite: $count');
  }

  Future<List<Reporte>> getReportesByTim(int tim) async {
    final db = await instance.database;

    final String query = '''
      SELECT reporte.*
      FROM reporte
      WHERE reporte.tim = ?
  ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [tim]);

    return List.generate(maps.length, (i) {
      return Reporte.fromMap(maps[i]);
    });
  }

  Future<List<int>> getTimsByMotivo(String motivo) async {
    final db = await instance.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'reporte_tim',
      columns: ['tim'],
      where: 'motivo = ?',
      whereArgs: [motivo],
    );

    return maps.map((map) => map['tim'] as int).toList();
  }

  Future<int> updateReporte(Reporte reporte) async {
    final db = await instance.database;

    final Map<String, dynamic> row = reporte.toMap();

    if (reporte.sku == null || reporte.tim == null) {
      throw Exception('El sku o tim no puede ser null para la actualización');
    }
    return await db.update(
      'reporte',
      row,
      where: 'sku = ? AND tim = ?',
      whereArgs: [reporte.sku, reporte.tim],
    );
  }

  Future<Producto?> buscarProductoPorCodigo(String codigo) async {
    try {
      final db = await instance.database;

      debugPrint('🔍 Buscando producto por código: $codigo');

      // 1️⃣ SKU exacto
      final sku = await db.query(
        'producto',
        where: 'sku = ?',
        whereArgs: [codigo],
        limit: 1,
      );

      if (sku.isNotEmpty) {
        debugPrint('✅ Encontrado por SKU');
        return Producto.fromMap(sku.first);
      }

      // 2️⃣ EAN exacto
      final ean = await db.query(
        'producto',
        where: 'ean = ?',
        whereArgs: [codigo],
        limit: 1,
      );

      if (ean.isNotEmpty) {
        debugPrint('✅ Encontrado por EAN');
        return Producto.fromMap(ean.first);
      }

      // 3️⃣ EAN parcial
      final parcial = await db.query(
        'producto',
        where: 'ean LIKE ?',
        whereArgs: ['%$codigo%'],
        limit: 1,
      );

      if (parcial.isNotEmpty) {
        debugPrint('✅ Encontrado por EAN parcial');
        return Producto.fromMap(parcial.first);
      }

      debugPrint('❌ Producto no encontrado');
      return null;
    } catch (e, stack) {
      debugPrint('💥 Error en buscarProductoPorCodigo');
      debugPrint('Código: $codigo');
      debugPrint('Error: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> insertReport(Reporte reporte) async {
    final db = await instance.database;

    final processedData = reporte.toMap();
    print(processedData);
    await db.insert('reporte', processedData);
  }

  Future<bool> hasProductos() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT EXISTS(SELECT 1 FROM producto LIMIT 1)');
    return result.first.values.first == 1;
  }

  Future<void> deleteProfundidad() async {
    final db = await instance.database;
    await db.delete('producto');
  }

  Future<void> deleteReporteTim(int tim) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('reporte', where: 'tim = ?', whereArgs: [tim]);
      await txn.delete('reporte_tim', where: 'tim = ?', whereArgs: [tim]);
    });
  }

  Future<int> deleteReporte(String sku, int tim) async {
    final db = await instance.database;
    return await db.delete(
      'reporte',
      where: 'sku = ? AND tim = ?',
      whereArgs: [sku, tim],
    );
  }
}
