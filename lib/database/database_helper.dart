import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reporte.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const sqlUbicacion = '''
    CREATE TABLE ubicacion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      division TEXT,
      subdpto TEXT,
      departamento TEXT,
      clase TEXT,
      subclase TEXT
    )
  ''';
      await db.execute(sqlUbicacion);
    }
    if (oldVersion < 3) {
      const sqlProducto = '''
    CREATE TABLE producto (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subdpto TEXT,
      proveedor TEXT,
      ean TEXT,
      sku TEXT,
      descripcion TEXT,
      marca TEXT,
      costoPromedio REAL,
      precioVigente REAL,
      casePack INTEGER,
      uMedida TEXT
    )
  ''';
      await db.execute(sqlProducto);
    }
    if (oldVersion < 4) {
      const sqlReporteTim = '''
        CREATE TABLE reporte_tim (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_generacion TEXT ,
          tim INTEGER,
          placa TEXT,            
          local_origen TEXT,    
          local_destino TEXT,   
          fecha_envio TEXT,
          motivo TEXT
        )
        ''';

      await db.execute(sqlReporteTim);
    }
  }

  Future _createDB(Database db, int version) async {
    const sql = '''
      CREATE TABLE reporte (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        observacion TEXT
      )
    ''';
    await db.execute(sql);

    const sqlUbicacion = '''
    CREATE TABLE ubicacion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      division TEXT,
      subdpto TEXT,
      departamento TEXT,
      clase TEXT,
      subclase TEXT
    )
  ''';
    await db.execute(sqlUbicacion);

    const sqlProducto = '''
    CREATE TABLE producto (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subdpto TEXT,
      proveedor TEXT,
      ean TEXT,
      sku TEXT,
      descripcion TEXT,
      marca TEXT,
      costoPromedio REAL,
      precioVigente REAL,
      casePack INTEGER,
      uMedida TEXT
    )
  ''';
    await db.execute(sqlProducto);

    const sqlReporteTim = '''
        CREATE TABLE reporte_tim (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_generacion TEXT ,
          tim INTEGER,    
          placa TEXT,            
          local_origen TEXT,    
          local_destino TEXT,   
          fecha_envio TEXT,
          motivo TEXT
        )
        ''';

    await db.execute(sqlReporteTim);
  }

  Future<List<Map<String, dynamic>>> searchByEan(String ean) async {
    final db = await instance.database;
    final String query = '''
    SELECT reporte.*
    FROM producto
    INNER JOIN reporte ON producto.sku = reporte.sku
    WHERE producto.ean = ?;
  ''';

    return await db.rawQuery(query, [ean]);
  }

  Future<void> insertReporteTim(ReporteTim reporteTim) async {
    final db = await instance.database;

    final result = await db.query(
      'reporte_tim',
      where: 'tim = ?',
      whereArgs: [reporteTim.tim],
    );

    if (result.isNotEmpty) {
      print('El tim ${reporteTim.tim} ya existe en la base de datos.');
      return;
    }
    await db.insert('reporte_tim', reporteTim.toMap());
    print('ReporteTim con tim ${reporteTim.tim} insertado correctamente.');
  }

  Future<List<ReporteTim>> getReporteTimByTim(int numeroTim) async {
    final db = await instance.database;

    final maps = await db.query(
      'reporte_tim',
      where: 'tim = ?', // Filtra por el TIM
      whereArgs: [numeroTim], //TIM como argumento para evitar inyecciones SQL
    );

    // Convierte los resultados en una lista de objetos ReporteTim
    return maps.map((map) => ReporteTim.fromMap(map)).toList();
  }

  Future<List<ReporteTim>> fetchReporteTim() async {
    final db = await instance.database;
    final maps = await db.query('reporte_tim');
    return maps.map((map) => ReporteTim.fromMap(map)).toList();
  }

  Future<void> insertProducto(Producto producto) async {
    final db = await instance.database;

    // Convertir el objeto Producto a un mapa
    final productoMap = producto.toMap();

    // Insertar el mapa en la tabla 'producto'

    await db.insert(
      'producto',
      productoMap,
      conflictAlgorithm: ConflictAlgorithm.replace, // Evita duplicados
    );
  }

  Future<List<Producto>> getProductos() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('producto');

    return List.generate(maps.length, (i) {
      return Producto.fromMap(maps[i]);
    });
  }

  // Future<List<Producto>> getProductosFiltrados(
  //     {String? descripcion, String? subdpto}) async {
  //   final db = await database;
  //   var query = 'SELECT * FROM producto';
  //   final params = <dynamic>[];
  //   final whereClauses = <String>[];

  //   if (descripcion != null && descripcion.isNotEmpty) {
  //     whereClauses.add('descripcion LIKE ?');
  //     params.add('%$descripcion%');
  //   }

  //   if (subdpto != null && subdpto.isNotEmpty) {
  //     whereClauses.add('subdpto LIKE ?');
  //     params.add('%$subdpto%');
  //   }

  //   if (whereClauses.isNotEmpty) {
  //     query += ' WHERE ${whereClauses.join(' AND ')}';
  //   }

  //   final result = await db.rawQuery(query, params);
  //   return result.map((map) => Producto.fromMap(map)).toList();
  // }
  Future<List<Producto>> getProductosFiltrados(
      {String? descripcion, String? subdpto}) async {
    final db = await database;
    var query = 'SELECT * FROM producto';
    final params = <dynamic>[];
    final whereClauses = <String>[];

    if (descripcion != null && descripcion.isNotEmpty) {
      whereClauses.add('descripcion LIKE ?');
      params.add('%$descripcion%');
    }

    if (subdpto != null && subdpto.isNotEmpty) {
      whereClauses.add('subdpto LIKE ?');
      params.add('%$subdpto%');
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }
    query += ' ORDER BY descripcion ASC, (uEnviadas > uRecibidas) DESC';

    final result = await db.rawQuery(query, params);
    return result.map((map) => Producto.fromMap(map)).toList();
  }

  Future<List<String>> getSubclasesUnicas() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT DISTINCT 
      TRIM(
        CASE 
          WHEN INSTR(subdpto, '-') > 0 
          THEN SUBSTR(subdpto, 1, INSTR(subdpto, '-') - 1)
          ELSE subdpto
        END
      ) as subdpto
    FROM producto
    WHERE subdpto IS NOT NULL
  ''');

    return result
        .where((row) => row['subdpto'] != null)
        .map((row) => row['subdpto'] as String)
        .toList();
  }

  Future<Producto?> getProductobyEan(String codigo) async {
    final db = await instance.database;

    String columna;
    if (codigo.length == 8) {
      columna = 'sku';
    } else if (codigo.length > 8) {
      columna = 'ean';
    } else {
      // Código inválido o muy corto
      return null;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'producto',
      where: '$columna LIKE ?',
      whereArgs: ['%$codigo%'],
    );

    if (maps.isNotEmpty) {
      return Producto.fromMap(maps.first);
    }

    return null;
  }

  Future<bool> hasProductos() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT EXISTS(SELECT 1 FROM producto LIMIT 1)');
    if (result.isNotEmpty) {
      final existsValue = result.first.values.first;
      return existsValue == 1 || existsValue == true;
    }
    return false;
  }

  Future<List<Reporte>> getReportesbyEan(String codigo) async {
    final db = await instance.database;

    String columna;
    if (codigo.length == 8) {
      columna = 'sku';
    } else if (codigo.length > 8) {
      columna = 'ean';
    } else {
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'reporte',
      where: '$columna LIKE ?',
      whereArgs: ['%$codigo%'],
    );

    if (maps.isNotEmpty) {
      return List.generate(maps.length, (i) {
        return Reporte.fromMap(maps[i]);
      });
    }

    return [];
  }

  // Future<void> insertUbicacion(Ubicacion ubicacion) async {
  //   final db = await instance.database;

  //   final List<Map<String, dynamic>> result = await db.query(
  //     'ubicacion',
  //     where:

  //         'division = ? AND subdpto = ? AND subdpto = ? AND clase = ? AND subclase = ?',
  //     whereArgs: [
  //       ubicacion.division,
  //       ubicacion.subdpto,
  //       ubicacion.subdpto,
  //       ubicacion.clase,
  //       ubicacion.subclase,
  //     ],
  //   );

  //   if (result.isEmpty) {
  //     final processedData = ubicacion.toMap();
  //     await db.insert('ubicacion', processedData);
  //   } else {
  //     print('Registro duplicado: ${ubicacion.toMap()}');
  //   }
  // }

  // Future<List<Ubicacion>> getUbicaciones() async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> maps = await db.query('ubicacion');

  //   return List.generate(maps.length, (i) {
  //     return Ubicacion.fromMap(maps[i]);
  //   });
  // }

  Future<int> insertProductoProf(Producto producto) async {
    final db = await instance.database;

    return await db.insert(
      'producto', // nombre de tu tabla
      {
        'subdpto': producto.subdpto,
        'proveedor': producto.proveedor,
        'ean': producto.ean,
        'sku': producto.sku,
        'descripcion': producto.descripcion,
        'marca': producto.marca,
        'costoPromedio': producto.costoPromedio,
        'precioVigente': producto.precioVigente,
        'casePack': producto.casePack,
        'uMedida': producto.uMedida,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertReport(Reporte reporte) async {
    final db = await instance.database;

    final processedData = reporte.toMap();
    print(processedData);
    await db.insert('reporte', processedData);
  }
  Future<void> insertReportsEnLote(List<Reporte> reportes) async {
  final db = await instance.database;

  final batch = db.batch();

  for (final reporte in reportes) {
    final processedData = reporte.toMap();
    print(processedData); // Puedes comentar esto si no lo necesitas
    batch.insert('reporte', processedData);
  }

  await batch.commit(noResult: true); // Ejecuta todos los inserts juntos
}


  Future<void> insertReportSinR(Reporte reporte) async {
    final db = await instance.database;

    final result = await db.query(
      'reporte',
      where: 'ean = ?',
      whereArgs: [reporte.sku],
    );
    if (result.isEmpty) {
      final processedData = reporte.toMap();
      await db.insert('reporte', processedData);
      print("Reporte insertado con éxito");
    } else {
      print("El reporte con el ean ${reporte.sku} ya existe.");
    }
  }

  Future<int> updateReporte(Reporte reporte) async {
    final db = await instance.database;

    final Map<String, dynamic> row = reporte.toMap();

    if (reporte.id == null) {
      throw Exception('El ID no puede ser null para la actualización');
    }
    return await db.update(
      'reporte',
      row,
      where: 'id = ?',
      whereArgs: [reporte.id],
    );
  }

  Future<Reporte?> getReportePorSku(String sku) async {
  final db = await instance.database;
  final maps = await db.query(
    'reporte',
    where: 'sku = ?',
    whereArgs: [sku],
    limit: 1,
  );

  if (maps.isNotEmpty) {
    return Reporte.fromMap(maps.first);
  } else {
    return null;
  }
}


  Future<bool> updateReporteDesdeServidor(String sku, String ean, String uMedida) async {
    final db = await instance.database;

    try {
      await db.update(
        'reporte',
        {'ean': ean,
        'uMedida': uMedida},
        where: 'sku = ?',
        whereArgs: [sku],
      );

      return true;
    } catch (e) {
      print('Error al actualizar: $e');
      return false;
    }
  }

  Future<bool> updateRecibidos(String id, double unidadesRecibidas) async {
    final db = await instance.database;

    try {
      int result = await db.update(
        'reporte',
        {'uRecibidas': unidadesRecibidas},
        where: 'id = ?',
        whereArgs: [id],
      );

      return result > 0;
    } catch (e) {
      print('Error al actualizar: $e');
      return false;
    }
  }

  Future<void> actualizarCamposReporteDesdeProducto(
      String sku, Producto producto) async {
    final db = await instance.database;

    final reporte = await db.update(
      'reporte',
      {
        'ean': producto.ean,
        'costoPromedio': producto.costoPromedio,
        'precioVigente': producto.precioVigente,
        'uMedida': producto.uMedida,
      },
      where: 'sku = ?',
      whereArgs: [sku],
    );
    print(reporte);
  }

  Future<List<Reporte>> getReportes() async {
    final db = await instance.database;

    final String query = '''
        SELECT *
        FROM 
          reporte
        ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query);

    return List.generate(maps.length, (i) {
      return Reporte.fromMap(maps[i]);
    });
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

  Future<List<int>> getTims() async {
    final db = await instance.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'reporte_tim',
      columns: ['tim'],
    );

    return maps.map((map) => map['tim'] as int).toList();
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

  // Future<List<Reporte>> getReportes() async {
  //   final db = await instance.database;

  //   final String query = '''
  //       SELECT
  //         r.id,
  //         r.olpn,
  //         r.pallet,
  //         r.tipo_inventario AS tipoInventario,
  //         r.tipo_sku AS tipoSku,
  //         r.subdpto AS subdpto,
  //         p.ean AS ean,
  //         r.sku,
  //         r.descripcion,
  //         r.casePack AS casePack,
  //         r.unidades,
  //         r.cajas,
  //         r.recibidos,
  //         r.fechavencimiento,
  //         r.observacion
  //       FROM
  //         reporte r
  //       LEFT JOIN
  //         producto p
  //       ON
  //         r.sku = p.sku
  //       ''';

  //   final List<Map<String, dynamic>> maps = await db.rawQuery(query);

  //   return List.generate(maps.length, (i) {
  //     return Reporte.fromMap(maps[i]);
  //   });
  // }

  Future<List<String>> getSubDepartments() async {
    final db = await database;
    const sql = '''
    SELECT DISTINCT subdpto
    FROM reporte
  ''';
    final List<Map<String, dynamic>> result = await db.rawQuery(sql);
    return result.map((row) => row['subdpto'] as String).toList();
  }

  Future<int> deleteReporte(int tim, String ean) async {
    final db = await instance.database;
    return await db.delete(
      'reporte',
      where: 'tim = ? AND ean = ?',
      whereArgs: [tim, ean],
    );
  }

  Future<int> deleteReporteWithCaja(int tim, String ean, String caja) async {
    final db = await instance.database;
    return await db.delete(
      'reporte',
      where: 'tim = ? AND ean = ? AND olpn = ?',
      whereArgs: [tim, ean, caja],
    );
  }

  Future<void> deleteProfundidad() async {
    final db = await instance.database;
    await db.delete('producto');
  }

  Future<void> deleteReportes(int tim) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      await txn.delete(
        'reporte',
        where: 'tim = ?',
        whereArgs: [tim],
      );

      await txn.delete(
        'reporte_tim',
        where: 'tim = ?', 
        whereArgs: [tim],
      );
    });
  }
}
