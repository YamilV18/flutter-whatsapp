import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class WhatsAppShareTestScreen extends StatefulWidget {
  @override
  _WhatsAppShareTestScreenState createState() =>
      _WhatsAppShareTestScreenState();
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
    _messageController.text =
        "¡Hola! Este es un mensaje de prueba desde Flutter.";
  }

  // Método para verificar y solicitar permisos
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Para Android 13+ (API 33+)
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
      if (await Permission.videos.isDenied) {
        await Permission.videos.request();
      }
      if (await Permission.audio.isDenied) {
        await Permission.audio.request();
      }

      // Para versiones anteriores de Android
      var storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        storageStatus = await Permission.storage.request();
      }

      var manageStorageStatus = await Permission.manageExternalStorage.status;
      if (manageStorageStatus.isDenied) {
        manageStorageStatus = await Permission.manageExternalStorage.request();
      }

      return storageStatus.isGranted ||
          manageStorageStatus.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.videos.isGranted;
    }
    return true;
  }

  // Método para seleccionar archivos (versión mejorada)
  Future<void> _pickFiles() async {
    try {
      // Verificar permisos primero
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showSnackBar(
          'Se necesitan permisos para acceder a archivos',
          Colors.red,
        );
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowCompression: true,
      );

      if (result != null) {
        List<File> newFiles = [];

        for (String? path in result.paths) {
          if (path != null) {
            File file = File(path);
            if (await file.exists()) {
              newFiles.add(file);
            }
          }
        }

        if (newFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(newFiles);
          });
          _showSnackBar(
            '${newFiles.length} archivo(s) agregado(s). Total: ${_selectedFiles.length}',
            Colors.green,
          );
        } else {
          _showSnackBar(
            'No se pudieron cargar los archivos seleccionados',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      _showSnackBar(
        'Error al seleccionar archivos: ${e.toString()}',
        Colors.red,
      );
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
      _showSnackBar('Error al abrir WhatsApp: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método mejorado para compartir archivos usando Share Plus
  Future<void> _shareFilesToWhatsApp() async {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Selecciona al menos un archivo', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verificar que todos los archivos existan
      List<File> validFiles = [];
      for (File file in _selectedFiles) {
        if (await file.exists()) {
          validFiles.add(file);
        }
      }

      if (validFiles.isEmpty) {
        _showSnackBar('No hay archivos válidos para compartir', Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      // Convertir a XFile para Share Plus
      List<XFile> xFiles = validFiles.map((file) => XFile(file.path)).toList();

      String shareText =
          _messageController.text.isNotEmpty
              ? _messageController.text
              : "Archivos compartidos desde Flutter";

      // Intentar compartir específicamente a WhatsApp primero
      if (Platform.isAndroid) {
        try {
          // Intentar abrir WhatsApp directamente con archivos
          await Share.shareXFiles(
            xFiles,
            text: shareText,
            subject: "Compartir archivos",
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
          _showSnackBar(
            'Archivos compartidos. Selecciona WhatsApp en el menú.',
            Colors.green,
          );
        } catch (e) {
          // Si falla, usar el método genérico
          await Share.shareXFiles(
            xFiles,
            text: shareText,
            subject: "Compartir archivos",
          );
          _showSnackBar(
            'Archivos listos para compartir. Selecciona WhatsApp.',
            Colors.green,
          );
        }
      } else {
        // Para iOS
        await Share.shareXFiles(
          xFiles,
          text: shareText,
          subject: "Compartir archivos",
        );
        _showSnackBar('Archivos compartidos correctamente', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error al compartir archivos: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método nuevo para enviar mensaje Y archivos juntos
  Future<void> _shareMessageAndFiles() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Por favor ingresa un número de teléfono', Colors.orange);
      return;
    }

    if (_messageController.text.isEmpty && _selectedFiles.isEmpty) {
      _showSnackBar('Ingresa un mensaje o selecciona archivos', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');

      // Si solo hay mensaje, usar WhatsApp Web/App
      if (_selectedFiles.isEmpty && _messageController.text.isNotEmpty) {
        await _shareTextToWhatsApp();
        return;
      }

      // Si hay archivos, usar Share Plus
      if (_selectedFiles.isNotEmpty) {
        // Verificar archivos válidos
        List<File> validFiles = [];
        for (File file in _selectedFiles) {
          if (await file.exists()) {
            validFiles.add(file);
          }
        }

        if (validFiles.isEmpty) {
          _showSnackBar('No hay archivos válidos para compartir', Colors.red);
          setState(() => _isLoading = false);
          return;
        }

        // Crear mensaje combinado
        String combinedMessage =
            _messageController.text.isNotEmpty
                ? "${_messageController.text}\n\n📱 Número: +$phone"
                : "📱 Número: +$phone\n\nArchivos compartidos desde Flutter";

        List<XFile> xFiles =
            validFiles.map((file) => XFile(file.path)).toList();

        await Share.shareXFiles(
          xFiles,
          text: combinedMessage,
          subject: "Mensaje y archivos para WhatsApp",
        );

        _showSnackBar(
          'Mensaje y archivos listos. Selecciona WhatsApp y envía al número: +$phone',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnackBar('Error al compartir: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método para crear archivo de prueba (mejorado)
  Future<void> _createTestFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'prueba_flutter_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      String content = '''
=== ARCHIVO DE PRUEBA FLUTTER ===
Creado: ${DateTime.now().toString()}
Número destino: ${_phoneController.text}
Mensaje: ${_messageController.text}

Este archivo fue generado automáticamente 
para probar la funcionalidad de compartir 
archivos a WhatsApp desde Flutter.

Tamaño de archivo: {content.length} caracteres
Archivos seleccionados: ${_selectedFiles.length}

¡Funciona correctamente! 🚀

--- Información técnica ---
Plataforma: ${Platform.operatingSystem}
Directorio: ${directory.path}
Nombre archivo: $fileName
      ''';

      await file.writeAsString(content);

      // Verificar que el archivo se creó correctamente
      if (await file.exists()) {
        setState(() {
          _selectedFiles.add(file);
        });
        _showSnackBar('Archivo de prueba creado: $fileName', Colors.green);
      } else {
        _showSnackBar('Error: No se pudo crear el archivo', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error al crear archivo: ${e.toString()}', Colors.red);
    }
  }

  // Método para limpiar archivos seleccionados
  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
    _showSnackBar('Archivos limpiados', Colors.blue);
  }

  // Método para eliminar archivo específico
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
    _showSnackBar('Archivo eliminado', Colors.orange);
  }

  // Método para obtener el tamaño total de archivos (mejorado)
  String _getTotalSize() {
    try {
      int totalBytes = 0;
      for (File file in _selectedFiles) {
        try {
          if (file.existsSync()) {
            totalBytes += file.lengthSync();
          }
        } catch (e) {
          // Ignorar archivos que no se pueden leer
        }
      }

      if (totalBytes < 1024) return '$totalBytes B';
      if (totalBytes < 1024 * 1024)
        return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      if (totalBytes < 1024 * 1024 * 1024)
        return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Error al calcular';
    }
  }

  // Método para obtener el nombre del archivo
  String _getFileName(File file) {
    return file.path.split('/').last;
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
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
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
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed:
                () => _showDialog(
                  'Información',
                  'Esta app permite enviar mensajes y archivos a WhatsApp.\n\n'
                      '• Mensajes: Se abren directamente en WhatsApp\n'
                      '• Archivos: Se comparten mediante el selector de apps\n'
                      '• Combinado: Mensaje + archivos juntos',
                ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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
                                '📱 Pantalla de Prueba - Funcionalidad Mejorada',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Envía mensajes y archivos a WhatsApp con funcionalidad completa.',
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
                          helperText: 'Incluye código de país sin +',
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

                      // Sección de archivos mejorada
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Archivos: ${_selectedFiles.length}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_selectedFiles.isNotEmpty)
                                    Text(
                                      'Tamaño: ${_getTotalSize()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),

                              if (_selectedFiles.isNotEmpty) ...[
                                Container(
                                  height: 120,
                                  child: ListView.builder(
                                    itemCount: _selectedFiles.length,
                                    itemBuilder: (context, index) {
                                      String fileName = _getFileName(
                                        _selectedFiles[index],
                                      );
                                      return Card(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.attach_file,
                                            color: Colors.blue,
                                          ),
                                          title: Text(
                                            fileName,
                                            style: TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            _selectedFiles[index].path,
                                            style: TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () => _removeFile(index),
                                          ),
                                          dense: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.folder_open,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No hay archivos seleccionados',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: 12),

                              // Botones para archivos
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _pickFiles,
                                      icon: Icon(Icons.folder_open),
                                      label: Text('Seleccionar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _createTestFile,
                                      icon: Icon(Icons.create_new_folder),
                                      label: Text('Crear Prueba'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          (_selectedFiles.isNotEmpty &&
                                                  !_isLoading)
                                              ? _clearFiles
                                              : null,
                                      icon: Icon(Icons.clear),
                                      label: Text('Limpiar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Botones principales mejorados
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _shareTextToWhatsApp,
                        icon:
                            _isLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(Icons.message),
                        label: Text('Solo Mensaje'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      SizedBox(height: 8),

                      ElevatedButton.icon(
                        onPressed:
                            (_isLoading || _selectedFiles.isEmpty)
                                ? null
                                : _shareFilesToWhatsApp,
                        icon:
                            _isLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(Icons.attach_file),
                        label: Text('Solo Archivos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      SizedBox(height: 8),

                      // Botón principal nuevo para enviar mensaje + archivos
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _shareMessageAndFiles,
                        icon:
                            _isLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(Icons.send),
                        label: Text('Mensaje + Archivos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF128C7E),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),

                      Spacer(),

                      // Información adicional mejorada
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '💡 Funcionalidades implementadas:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• Envío de mensajes directos a WhatsApp\n'
                                '• Selección múltiple de archivos reales\n'
                                '• Combinación de mensaje + archivos\n'
                                '• Gestión de permisos automática\n'
                                '• Validación de archivos existentes',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
