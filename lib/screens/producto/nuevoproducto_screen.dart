import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:flutter/material.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporte_model.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Reporte? reporte;

  const AgregarProductoScreen({Key? key, this.reporte}) : super(key: key);

  @override
  _AgregarProductoScreenState createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _unidadSeleccionada;
  List<String> unidadMedida = ['UN', 'KG'];

  TextEditingController _subdptoController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _eanController = TextEditingController();
  final _skuController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _marcaController = TextEditingController();
  final _costoController = TextEditingController();
  final _precioController = TextEditingController();
  final _casePackController = TextEditingController();
  final _uMedidaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.reporte != null) {
      final reporte = widget.reporte!;
      _subdptoController.text = reporte.subdpto;
      _skuController.text = reporte.sku;
      _descripcionController.text = reporte.descripcion;
      _casePackController.text = reporte.casePack.toString();
      // Puedes continuar con más campos si tu modelo los tiene.
    }
  }

  @override
  void dispose() {
    _subdptoController.dispose();
    _proveedorController.dispose();
    _eanController.dispose();
    _skuController.dispose();
    _descripcionController.dispose();
    _marcaController.dispose();
    _costoController.dispose();
    _precioController.dispose();
    _casePackController.dispose();
    _uMedidaController.dispose();
    super.dispose();
  }

  void _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      final nuevoProducto = Producto(
        id: null,
        subdpto: _subdptoController.text,
        proveedor: _proveedorController.text,
        ean: _eanController.text,
        sku: _skuController.text,
        descripcion: _descripcionController.text,
        marca: _marcaController.text,
        costoPromedio: double.tryParse(_costoController.text) ?? 0,
        precioVigente: double.tryParse(_precioController.text) ?? 0,
        casePack: int.tryParse(_casePackController.text) ?? 0,
        isContable: false,
        marcaSensible: false,
        uMedida: _uMedidaController.text,
      );
      final dialogContext = await loading.instance.showLoadingDialog(context, 'Actualizando producto');
      try {
        final service = ProductoService();
        await service.actualizarProducto(context, nuevoProducto);
        Navigator.pop(dialogContext); // Cierra el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto se actualizó con éxito')),
        );
        Navigator.pop(context, {'guardado': true, 'ean': nuevoProducto.ean, 'uMedida': nuevoProducto.uMedida}); 
      } catch (e) {
        Navigator.pop(dialogContext); // Cierra el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el producto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Producto Nuevo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(_subdptoController, 'Sub Departamento'),
              _buildTextField(_proveedorController, 'Proveedor'),
              TextFormField(
                controller: _eanController,
                decoration: InputDecoration(
                  labelText: 'EAN',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: _eanController.text.isEmpty
                        ? Icon(Icons.qr_code, color: Colors.amber)
                        : Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      if (_eanController.text.isEmpty) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => BarcodeScannerSimple()),
                        );
                        if (result != null) {
                          setState(() {
                            _eanController.text = result.toString().trim();
                          });
                        }
                      } else {
                        setState(() {
                          _eanController.clear();
                        });
                      }
                    },
                  ),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                ),
                onChanged: (value) =>
                    setState(() {}), // Para actualizar el icono
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
              ),
              _buildTextField(_skuController, 'SKU'),
              _buildTextField(_descripcionController, 'Descripción'),
              _buildTextField(_marcaController, 'Marca'),
              _buildTextField(_costoController, 'Costo Promedio',
                  isNumeric: true),
              _buildTextField(_precioController, 'Precio Vigente',
                  isNumeric: true),
              _buildTextField(_casePackController, 'Case Pack',
                  isNumeric: true),
              DropdownButtonFormField<String>(
                value: _unidadSeleccionada,
                items: unidadMedida.map((String unidad) {
                  return DropdownMenuItem<String>(
                    value: unidad,
                    child: Text(unidad),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _unidadSeleccionada = newValue;
                    _uMedidaController.text = newValue ?? '';
                  });
                },
                decoration: InputDecoration(labelText: 'Unidad de Medida'),
                validator: (value) =>
                    value == null ? 'Seleccione una unidad' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardarProducto,
                child: Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) => null,
      // value == null || value.isEmpty ? 'Campo obligatorio' : null,
    );
  }
}
