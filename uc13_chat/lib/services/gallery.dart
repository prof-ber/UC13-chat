import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'dart:ui' as ui;

final SERVER_IP = '172.17.9.224';

class FileService {
  static const List<String> _videoExtensions = ['mp4', 'avi', 'mov'];
  static const List<String> _imageExtensions = ['jpg', 'jpeg', 'png'];

  static Future<Size> getImageDimensions(String imagePath) async {
    final File file = File(imagePath);
    final Uint8List bytes = await file.readAsBytes();
    final ui.Image image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  static Future<Map<String, dynamic>?> uploadFile(
    BuildContext context, {
    bool isVideo = false,
  }) async {
    FilePickerResult? result;
    File? pickedFile;

    try {
      if (kIsWeb) {
        // Web platform handling
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: isVideo ? _videoExtensions : _imageExtensions,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          print("File picked on web platform: ${result.files.first.name}");
        }
      } else if (Platform.isWindows) {
        // Windows-specific file picking
        final file_selector.XTypeGroup typeGroup = file_selector.XTypeGroup(
          label: isVideo ? 'videos' : 'images',
          extensions: isVideo ? _videoExtensions : _imageExtensions,
        );

        final file_selector.XFile? result = await file_selector.openFile(
          acceptedTypeGroups: [typeGroup],
        );

        if (result != null) {
          pickedFile = File(result.path);
          print("File picked on Windows: ${pickedFile.path}");
        }
      } else {
        // Mobile platforms
        final ImagePicker _picker = ImagePicker();
        XFile? tempFile;
        if (isVideo) {
          tempFile = await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 10),
          );
        } else {
          tempFile = await _picker.pickImage(source: ImageSource.gallery);
        }
        if (tempFile != null) {
          pickedFile = File(tempFile.path);
          print("File picked on mobile: ${pickedFile.path}");

          // Validate file extension for mobile
          String extension = pickedFile.path.split('.').last.toLowerCase();
          List<String> allowedExtensions =
              isVideo ? _videoExtensions : _imageExtensions;
          if (!allowedExtensions.contains(extension)) {
            throw Exception(
              'Invalid file type. Allowed types: ${allowedExtensions.join(", ")}',
            );
          }
        }
      }

      if (pickedFile == null && (result == null || result.files.isEmpty)) {
        throw Exception('No file selected');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      var uri = Uri.parse('http://$SERVER_IP:3000/api/upload');
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      if (kIsWeb) {
        // Web handling
        if (result != null && result.files.isNotEmpty) {
          var file = result.files.first;
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        }
      } else {
        if (pickedFile != null) {
          if (isVideo) {
            final compressedVideo = await compressVideo(pickedFile.path);
            request.files.add(
              await http.MultipartFile.fromPath('file', compressedVideo.path!),
            );
          } else {
            final compressedFile = await compressImage(pickedFile);
            request.files.add(
              await http.MultipartFile.fromPath('file', compressedFile.path),
            );
          }
        }
      }

      print("Sending request to server...");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print("Full response: $responseData");
        if (responseData['file'] != null &&
            responseData['file']['url'] != null) {
          String url = responseData['file']['url'];
          Size? dimensions;
          if (!isVideo && !kIsWeb && pickedFile != null) {
            dimensions = await getImageDimensions(pickedFile.path);
          }
          return {
            'url': url,
            'width': dimensions?.width,
            'height': dimensions?.height,
          };
        } else {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      print("Error in uploadFile: $error");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $error')));
      return null;
    }
  }

  static Future<File> compressImage(File file) async {
    if (kIsWeb) {
      // Return the original file for web platform
      return file;
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Get the original file size
    int originalSize = await file.length();
    print('Original size: ${originalSize / 1024} KB');

    int quality = 85;
    int minWidth = 1024;
    int minHeight = 1024;
    File compressedFile = file;
    int compressedSize = originalSize;

    while (compressedSize > 200000 && quality >= 50) {
      // 200 KB limit
      var result = await FlutterImageCompress.compressAndGetFile(
        compressedFile.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw Exception('Image compression failed');
      }

      compressedFile = File(result.path);
      compressedSize = await compressedFile.length();

      print(
        'Compressed size: ${compressedSize / 1024} KB (Quality: $quality, Dimensions: ${minWidth}x$minHeight)',
      );

      // Reduce quality and dimensions for next iteration if still too large
      quality -= 5;
      minWidth = (minWidth * 0.9).round();
      minHeight = (minHeight * 0.9).round();

      // Ensure we don't go below minimum dimensions
      minWidth = minWidth.clamp(300, 1024);
      minHeight = minHeight.clamp(300, 1024);
    }

    if (compressedSize > 200000) {
      print(
        'Warning: Could not compress image below 200 KB. Final size: ${compressedSize / 1024} KB',
      );
    }

    return compressedFile;
  }

  static Future<MediaInfo> compressVideo(String videoPath) async {
    MediaInfo? info = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (info == null) {
      throw Exception('Video compression failed');
    }
    return info;
  }
}
