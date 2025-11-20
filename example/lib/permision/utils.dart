
import 'package:permission_handler/permission_handler.dart';

class Utils {
  // helper para pedir permisos
  Future<void> requestPermissions() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.photos.request();
    await Permission.phone.request();
  }
}