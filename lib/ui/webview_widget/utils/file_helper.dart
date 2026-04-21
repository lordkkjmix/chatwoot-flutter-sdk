import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

//import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';

Future<File?> uploadFile(io.File file,
    {int targetWidth = 400}) async {
  File? compressedFile = await compressImage(file, targetWidth);
  if (compressedFile == null) return null;
  return compressedFile;
}

Future<File?> compressImage(File file, int maxSize) async {
  final properties = await decodeImageFile(file.path);
  if (properties == null) return null;
  if (properties.width <= maxSize && properties.height <= maxSize) {
    return file;
  }

  var newWidth = 0;
  var newHeight = 0;

  if (properties.width > properties.height) {
    newWidth = maxSize;
    // Calcular la altura manteniendo la relación de aspecto
    newHeight = ((properties.height * maxSize) / properties.width).round();
  } else {
    // Calcular el ancho manteniendo la relación de aspecto
    newWidth = ((properties.width * maxSize) / properties.height).round();
    newHeight = maxSize;
  }

  return compressImageFile(
    file,
    minHeight: newHeight,
    minWidth: newWidth,
    format: CompressFormat.png,
  );
}

Future<File> compressImageFile(
  File file, {
  int? minWidth,
  int? minHeight,
  int? quality,
  int? rotate,
  bool? autoCorrectionAngle,
  CompressFormat? format,
  bool? keepExif,
  int? numberOfRetries,
}) async {
  final fileTemp = await createTemporaryImageFile();
  final fileSize = await file.length(); // Tamaño en bytes
  debugPrint('Tamaño del archivo: $fileSize bytes');
  final compressedFile = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    fileTemp.path,
    minWidth: minWidth ?? 1920,
    minHeight: minHeight ?? 1080,
    quality: quality ?? 95,
    rotate: rotate ?? 0,
    autoCorrectionAngle: autoCorrectionAngle ?? true,
    format: format ?? CompressFormat.jpeg,
    keepExif: keepExif ?? false,
    numberOfRetries: numberOfRetries ?? 5,
  );
  final fileSizeTemp =
      await File(compressedFile!.path).length(); // Tamaño en bytes
  debugPrint('Tamaño del archivo nuevo: $fileSizeTemp bytes');
  return File(compressedFile.path);
}

Future<File> createTemporaryImageFile() async {
  final directory = await getTemporaryDirectory();
  final path = directory.path;
  return File('$path/${DateTime.now().microsecondsSinceEpoch}image.png');
}
