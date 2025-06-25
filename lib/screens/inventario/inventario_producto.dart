
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:flutter/material.dart';

class InventarioProducto extends StatefulWidget {
  final String motivo;

  const InventarioProducto({Key? key, required this.motivo}) : super(key: key);

  @override
  _InventarioProducto createState() => _InventarioProducto();
}

class _InventarioProducto extends State<InventarioProducto> {
  List<Reporte> _productosBySku = [];
  List<Reporte> _productosFiltrados = [];
  String? _eanFiltro;
  bool _filtrosVisbles = true;

  bool activarTodo = false;

  List<int> reportesInfo = [];

  // TextEditingController _dateDesdeController = TextEditingController();
  // TextEditingController _dateHastaController = TextEditingController();
  TextEditingController _codigoController = TextEditingController();
  // DateTime? _selectedDesdeDate;
  // DateTime? _selectedHastaDate;

  String? cajaAddOlpn;
  double? unidadesAddTim;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    try {
      final serviceR = ReporteService();
      final reporteInfo =
          await serviceR.buscarPorMotivo(widget.motivo);

      setState(() {
        reportesInfo = reporteInfo;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  Future<void> _actualizarFiltro() async {
    final serviceDR = DetalleReporteService();
    final productosEncontrados = await serviceDR.detalleReportesInventario(widget.motivo, _eanFiltro!);
    setState(() async {
      _productosBySku =
          await DatabaseHelper.instance.getReportesbyEan(_eanFiltro!);
      _productosFiltrados = _productosBySku
          .where((producto) => reportesInfo.contains(producto.tim))
          .toList();
    });
  }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            // await _reCargaProductos();
            _actualizarFiltro();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            Text('Ubicar Producto', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: _filtrosVisbles
                ? Icon(Icons.filter_list_off)
                : Icon(Icons.filter_list),
            onPressed: () => {
              setState(() {
                _filtrosVisbles = !_filtrosVisbles;
              })
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
                visible: _filtrosVisbles,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codigoController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: AppColors.amber),
                              ),
                              suffixIcon: IconButton(
                                icon: _eanFiltro == null || _eanFiltro!.isEmpty
                                    ? Icon(
                                        Icons.qr_code,
                                        color: Colors.amber,
                                      )
                                    : Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                onPressed: () async {
                                  if (_eanFiltro == null ||
                                      _eanFiltro!.isEmpty) {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BarcodeScannerSimple(),
                                      ),
                                    );

                                    if (result != null) {
                                      setState(() {
                                        _codigoController.text = result;
                                        _eanFiltro = result.toString().trim();
                                      });
                                      await _actualizarFiltro();
                                    }
                                  } else {
                                    setState(() {
                                      _codigoController.clear();
                                      _eanFiltro = null;
                                      _productosFiltrados = [];
                                    });
                                    await _actualizarFiltro();
                                  }
                                },
                              ),
                              labelText: 'Sku/Ean',
                              filled: false,
                              fillColor: Colors.grey[200],
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 8.0),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _eanFiltro = value;
                              });
                              _actualizarFiltro();
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                      ],
                    ),
                    SizedBox(height: 12),
                  ],
                )),
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No se encontró el producto, intenta escanear otro producto',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 28),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            height: _filtrosVisbles ? 500 : 615,
                            child: ListView.builder(
                              itemCount: _productosFiltrados.length,
                              itemBuilder: (context, index) {
                                var producto = _productosFiltrados[index];
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${index}. ' +
                                                producto.descripcion.trim(),
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Pallet # ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.tim}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Sku:  ${producto.sku}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Caja # ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.olpn}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      RichText(
                                                        text: TextSpan(
                                                          children: [
                                                            const TextSpan(
                                                              text:
                                                                  'Case Pack: ',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  '${producto.casePack.toString()}',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Cajas: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.uEnviadas/producto.casePack}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (producto.uRecibidas != 0)
                                                    Row(
                                                      children: [
                                                        RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              const TextSpan(
                                                                text:
                                                                    'Unidades: ',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    '${producto.uRecibidas.toString()}',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _showReportDetails(context, producto);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // 🔵 NUEVO: Cuadro para unidades totales
                              Container(
                                height: 40,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                margin: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Unidades: ${_productosFiltrados.fold<double>(0, (suma, item) => suma + (item.uRecibidas))}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 🔵 Original: Cuadro para cantidad de productos
                              Container(
                                height: 40,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                margin: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Productos: ${_productosFiltrados.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
