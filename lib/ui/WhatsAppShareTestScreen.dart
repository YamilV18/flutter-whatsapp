import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class WhatsAppShareTestScreen extends StatefulWidget {
  @override
  _WhatsAppShareTestScreenState createState() => _WhatsAppShareTestScreenState();
}

class _WhatsAppShareTestScreenState extends State<WhatsAppShareTestScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  List<File> _selectedFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Número de prueba predeterminado (sin +)
    _phoneController.text = "51987654321";
    _messageController.text = "¡Hola! Este es un mensaje de prueba desde Flutter.";
  }

  // Método para verificar y solicitar permisos
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }

      // Para Android 13+ también necesitamos estos permisos específicos
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
      if (await Permission.videos.isDenied) {
        await Permission.videos.request();
      }

      return status.isGranted || status.isLimited;
    }
    return true;
  }

  // Método para seleccionar archivos (versión real)
  Future<void> _pickFiles() async {
    try {
      // Verificar permisos primero
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showSnackBar('Se necesitan permisos para acceder a archivos', Colors.red);
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: null,
      );

      if (result != null) {
        List<File> newFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        setState(() {
          _selectedFiles.addAll(newFiles);
        });

        _showSnackBar('${newFiles.length} archivo(s) agregado(s). Total: ${_selectedFiles.length}', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar archivos: $e', Colors.red);
    }
  }

  // Método para compartir solo texto via URL de WhatsApp
  Future<void> _shareTextToWhatsApp() async {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar('Por favor completa el número y mensaje', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      String message = Uri.encodeComponent(_messageController.text);

      // URL de WhatsApp para enviar mensaje directo
      String whatsappUrl = "https://wa.me/$phone?text=$message";

      Uri uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('WhatsApp abierto correctamente', Colors.green);
      } else {
        _showSnackBar('WhatsApp no está instalado', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error al abrir WhatsApp: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método para compartir archivos usando Share Plus (real)
  Future<void> _shareFilesToWhatsApp() async {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Selecciona al menos un archivo', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<XFile> xFiles = _selectedFiles.map((file) => XFile(file.path)).toList();

      String shareText = _messageController.text.isNotEmpty
          ? _messageController.text
          : "Archivos compartidos desde Flutter";

      // Compartir archivos reales
      await Share.shareXFiles(
        xFiles,
        text: shareText,
        subject: "Compartir archivos",
      );

      _showSnackBar('Archivos compartidos correctamente', Colors.green);
    } catch (e) {
      _showSnackBar('Error al compartir archivos: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método para crear archivo de prueba (real)
  Future<void> _createTestFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'prueba_flutter_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      String content = '''
=== ARCHIVO DE PRUEBA FLUTTER ===
Creado: ${DateTime.now().toString()}
Número destino: ${_phoneController.text}
Mensaje: ${_messageController.text}

Este archivo fue generado automáticamente 
para probar la funcionalidad de compartir 
archivos a WhatsApp desde Flutter.

¡Funciona correctamente! 🚀
      ''';

      await file.writeAsString(content);

      setState(() {
        _selectedFiles.add(file);
      });

      _showSnackBar('Archivo de prueba creado: $fileName', Colors.green);
    } catch (e) {
      _showSnackBar('Error al crear archivo: $e', Colors.red);
    }
  }

  // Método para limpiar archivos seleccionados
  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
    _showSnackBar('Archivos limpiados', Colors.blue);
  }

  // Método para obtener el tamaño total de archivos
  String _getTotalSize() {
    try {
      int totalBytes = _selectedFiles.fold(0, (sum, file) {
        try {
          return sum + file.lengthSync();
        } catch (e) {
          return sum;
        }
      });

      if (totalBytes < 1024) return '$totalBytes B';
      if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Calculando...';
    }
  }

  // Método para mostrar diálogos informativos
  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  // Método para mostrar SnackBar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prueba WhatsApp Share'),
        backgroundColor: Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información de prueba
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Pantalla de Prueba',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esta es una simulación para probar el compartir información a WhatsApp sin backend.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Campo de número de teléfono
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Número de WhatsApp',
                hintText: '51987654321',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),

            SizedBox(height: 16),

            // Campo de mensaje
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Escribe tu mensaje aquí...',
                prefixIcon: Icon(Icons.message),
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            // Sección de archivos
            Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archivos seleccionados: ${_selectedFiles.length}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    if (_selectedFiles.isNotEmpty) ...[
                      Container(
                        height: 100,
                        child: ListView.builder(
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            String fileName = _selectedFiles[index].toString();
                            return ListTile(
                              leading: Icon(Icons.attach_file),
                              title: Text(fileName),
                              subtitle: Text('Archivo simulado para prueba'),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      Text('No hay archivos seleccionados'),
                    ],

                    SizedBox(height: 12),

                    // Botones para archivos
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickFiles,
                            icon: Icon(Icons.folder_open),
                            label: Text('Seleccionar'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _createTestFile,
                            icon: Icon(Icons.create_new_folder),
                            label: Text('Crear Prueba'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedFiles.isNotEmpty ? _clearFiles : null,
                            icon: Icon(Icons.clear),
                            label: Text('Limpiar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Botones principales
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _shareTextToWhatsApp,
              icon: _isLoading ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ) : Icon(Icons.message),
              label: Text('Enviar Mensaje a WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: (_isLoading || _selectedFiles.isEmpty) ? null : _shareFilesToWhatsApp,
              icon: _isLoading ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ) : Icon(Icons.share),
              label: Text('Compartir Archivos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            Spacer(),

            // Información adicional
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Notas de prueba:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• El mensaje abre WhatsApp directamente\n'
                          '• Los archivos usan el selector nativo de Android\n'
                          '• Sin backend: todo funciona localmente',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}