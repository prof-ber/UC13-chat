import 'package:flutter/material.dart';
import 'gallery.dart';
import 'package:uc13_chat/appconstants.dart';

class FileUploadService {
  // Main method for uploading files
  static Future<Map<String, dynamic>?> uploadFile(
    BuildContext context, {
    required bool isVideo,
  }) async {
    try {
      final result = await FileService.uploadFile(context, isVideo: isVideo);
      print('Upload result: $result');
      if (result != null && result['url'] != null) {
        print('File uploaded successfully: ${result['url']}');
        print('Width: ${result['width']}, Height: ${result['height']}');

        // Default dimensions if they're null
        double defaultWidth = isVideo ? 320 : 200;
        double defaultHeight = isVideo ? 240 : 200;

        return {
          'url': result['url'] as String,
          'width': (result['width'] as num?)?.toDouble() ?? defaultWidth,
          'height': (result['height'] as num?)?.toDouble() ?? defaultHeight,
          'fileType': isVideo ? 'video' : 'image',
        };
      } else {
        throw Exception('File upload failed: No URL returned');
      }
    } catch (e) {
      print('Error in uploadFile: $e');
      _showErrorSnackBar(context, 'Failed to upload file: $e');
      return null;
    }
  }

  // Method to build and display uploaded images
  static Widget buildMessageImage(
    String? imageUrl,
    double? width,
    double? height,
  ) {
    if (imageUrl == null) {
      print("Image URL is null");
      return SizedBox.shrink();
    }

    final fullImageUrl = _getFullImageUrl(imageUrl);
    print("Attempting to load image from: $fullImageUrl");
    print("Width: $width, Height: $height");

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        fullImageUrl,
        width: width ?? 200,
        height: height ?? 200,
        fit: BoxFit.cover,
        loadingBuilder: _imageLoadingBuilder,
        errorBuilder: _imageErrorBuilder,
      ),
    );
  }

  // Utility method for formatting time
  static String formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  // Private helper methods
  static String _getFullImageUrl(String imageUrl) {
    return imageUrl.startsWith('http')
        ? imageUrl
        : 'http://${AppConstants.SERVER_IP}:3000$imageUrl';
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 5)),
    );
  }

  static Widget _imageLoadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) {
      print("Image loaded successfully");
      return child;
    }
    print(
      "Loading image: ${loadingProgress.cumulativeBytesLoaded} / ${loadingProgress.expectedTotalBytes}",
    );
    return Center(
      child: CircularProgressIndicator(
        value:
            loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
      ),
    );
  }

  static Widget _imageErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    print("Error loading image: $error");
    print("Stack trace: $stackTrace");
    return Column(
      children: [
        Icon(Icons.error),
        Text('Failed to load image', style: TextStyle(color: Colors.red)),
      ],
    );
  }
}
