import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/screens/producto/nuevoproducto_screen.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:flutter/material.dart';

class ReportDetailsDialog extends StatefulWidget {
  final Reporte report;
  final VoidCallback onSave;

  const ReportDetailsDialog(
      {Key? key, required this.report, required this.onSave})
      : super(key: key);

  @override
  _DetalleReporteDialogState createState() => _DetalleReporteDialogState();
}

class _DetalleReporteDialogState extends State<ReportDetailsDialog> {
  late double _count;
  DateTime? selectedDate;
  bool nuevoProducto = false;

  final TextEditingController _controller = TextEditingController();
  TextEditingController dateController = TextEditingController();

  String formatDoubleSmart(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString(); // Quita los decimales si es entero
    } else {
      return value.toString(); // Muestra el decimal si existe
    }
  }

  @override
  void initState() {
    super.initState();
    dateController.text = widget.report.fechavencimiento.isEmpty
        ? ""
        : widget.report.fechavencimiento;
    _count = widget.report.uRecibidas; //
    _controller.text = formatDoubleSmart(_count);
  }

  void _increment() {
    setState(() {
      _count = _count + widget.report.casePack;
      _controller.text = formatDoubleSmart(_count);
    });
  }

  void _decrement() {
    if (_count > 0) {
      setState(() {
        _count--;
        _controller.text = formatDoubleSmart(_count);
      });
    }
  }

  void _updateCount(String value) {
    double? newValue = double.tryParse(value);
    if (newValue != null) {
      setState(() {
        _count = newValue;
      });
    } else if (value.isEmpty) {
      setState(() {
        _count = 0;
        _controller.text = formatDoubleSmart(_count);
      });
    }
  }

  @override
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.report.descripcion}',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.start,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.report.sku}',
                  decoration: InputDecoration(
                    labelText: 'SKU',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.3,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 30),
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.report.subdpto}',
                  decoration: InputDecoration(
                    labelText: 'SubDpto',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 30),
              Expanded(
                child: TextFormField(
                  initialValue: widget.report.ean,
                  decoration: InputDecoration(
                    labelText: 'EAN',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.report.casePack}',
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'CasePack',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue:
                      '${widget.report.uEnviadas / widget.report.casePack}',
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Cajas',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.report.uEnviadas}',
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Unidades',
                    labelStyle: TextStyle(
                      color: Colors.blue,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  //readOnly: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  controller: dateController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'F. Vencimiento',
                    border: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.black, width: 2.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          String formattedDate =
                              '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                          setState(() {
                            dateController.text = formattedDate;
                          });
                        }
                      },
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (value) {
                    // Validar si el usuario escribe una fecha válida (dd/MM/yyyy)
                    RegExp dateRegex = RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$');
                    if (!dateRegex.hasMatch(value)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('La fecha no es válida')),
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text(
                  //   'U. Recibidas:',
                  //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  // ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _controller,
                          textAlign: TextAlign.center,
                          onChanged: _updateCount,
                          decoration: InputDecoration(
                            labelText: 'U. Cont',
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.black, width: 2.0),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                          ),
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _increment,
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: 24,
                            ),
                          ),
                          GestureDetector(
                            onTap: _decrement,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (widget.report.uEnviadas > _count)
            Text(
              '${widget.report.uEnviadas - _count} Faltantes',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            )
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(width: 10),
            //200525
            if (widget.report.ean.isEmpty)
              TextButton(
                onPressed: () async {
                  final response = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AgregarProductoScreen(reporte: widget.report),
                    ),
                  );
                  if (response != null && response['guardado'] == true) {
                    Reporte reporteActualizado = Reporte(
                      tim: widget.report.tim,
                      id: widget.report.id,
                      olpn: widget.report.olpn,
                      subdpto: widget.report.subdpto,
                      ean: response['ean'],
                      descripcion: widget.report.descripcion,
                      casePack: widget.report.casePack,
                      uMedida: response['uMedida'],
                      precioVigente: widget.report.precioVigente,
                      costoPromedio: widget.report.costoPromedio,
                      sku: widget.report.sku,
                      uEnviadas: widget.report.uEnviadas,
                      uRecibidas: double.tryParse(_controller.text) ??
                          widget.report.uRecibidas,
                      fechavencimiento: dateController.text,
                      observacion: widget.report.observacion,
                    );
                    widget.onSave();
                    Navigator.pop(context, reporteActualizado);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text(
                  'Nuevo Producto',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            SizedBox(width: 10),
            TextButton(
              onPressed: () async {
                final serviceDR = DetalleReporteService();
                Reporte reporteActualizado = Reporte(
                  tim: widget.report.tim,
                  id: widget.report.id,
                  olpn: widget.report.olpn,
                  subdpto: widget.report.subdpto,
                  ean: widget.report.ean,
                  descripcion: widget.report.descripcion,
                  casePack: widget.report.casePack,
                  uMedida: widget.report.uMedida,
                  precioVigente: widget.report.precioVigente,
                  costoPromedio: widget.report.costoPromedio,
                  sku: widget.report.sku,
                  uEnviadas: widget.report.uEnviadas,
                  uRecibidas: double.tryParse(_controller.text) ??
                      widget.report.uRecibidas,
                  fechavencimiento: dateController.text,
                  observacion: widget.report.observacion,
                );
                final dialogContext = await loading.instance
                    .showLoadingDialog(context, 'Actualizando Producto');
                int result =
                    await serviceDR.actualizarDatosDetalle(reporteActualizado, widget.report.tim.toString());
                if (result > 0) {
                  widget.onSave();
                  Navigator.of(dialogContext).pop();
                  Navigator.pop(context, reporteActualizado);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar el reporte')),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        )
      ],
    );
  }
}
