import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/usuario_model.dart';

class UserRepository {
  Future<void> saveUser(Usuario usuario) async {
    try {
      print("🟡 saveUser() → obteniendo DB...");
      final db = await DatabaseHelper.instance.database;

      print("🟡 DB obtenida, iniciando DELETE app_user...");

      final result =
          await db.delete("app_user").timeout(const Duration(seconds: 5));

      print("🟢 DELETE app_user OK → filas: $result");

      print("🟡 INSERT app_user...");
      await db.insert("app_user", usuario.toMap());

      print("🟢 INSERT app_user OK");
    } catch (e, st) {
      print("🔴 ERROR EN saveUser()");
      print(e);
      print(st);
      rethrow;
    }
  }

  Future<Usuario?> getUser() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query("app_user", limit: 1);

    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  Future<String?> getNombreUsuario() async {
    final user = await getUser();
    return user?.nombre;
  }

  Future<String?> getToken() async {
    final user = await getUser();
    return user?.token;
  }

  Future<void> logout() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete("app_user");
  }
}
