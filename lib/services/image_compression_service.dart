import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Downscales and re-encodes picked images before they are stored or served.
///
/// The real saving is **resolution**, not encoder quality: a 12MP phone photo
/// is ~4000px wide, but it is only ever shown on a projector or browser at
/// 1080p–4K. Discarding pixels nobody can see cuts file size by an order of
/// magnitude with no visible difference, which matters here because every
/// canvas/background image is fetched over LAN by each connected display.
///
/// Compression is lossy (JPEG/WebP), so this is not bit-for-bit lossless — but
/// at [_quality] on a downscaled image the difference is imperceptible when
/// projected. Anything that fails to compress falls back to the original file
/// rather than blocking the user mid-service.
class ImageCompressionService {
  /// Long-edge cap. 3840 keeps 4K projectors pixel-perfect while still cutting
  /// a 12MP phone photo roughly in half on each axis.
  static const int _maxDimension = 3840;

  /// Below this, re-encoding costs more quality than the bytes it saves.
  static const int _skipBelowBytes = 400 * 1024;

  static const int _quality = 88;

  /// Formats the compressor can actually decode. GIF is excluded deliberately:
  /// re-encoding would flatten animation to a single frame.
  static const Set<String> _compressible = {'.jpg', '.jpeg', '.png', '.webp'};

  /// Compresses [source] into the app's documents directory and returns the new
  /// file. Returns [source] unchanged when compression is skipped or fails, so
  /// callers can treat the result as "the file to use" without null handling.
  Future<File> compress(
    File source, {
    String subdirectory = 'compressed',
  }) async {
    try {
      final extension = path.extension(source.path).toLowerCase();
      if (!_compressible.contains(extension)) return source;

      final originalBytes = await source.length();
      if (originalBytes < _skipBelowBytes) return source;

      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(path.join(appDir.path, subdirectory));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // PNGs may carry transparency that JPEG would flatten to black, so keep
      // them as PNG; everything else re-encodes to JPEG for the better ratio.
      final isPng = extension == '.png';
      final format = isPng ? CompressFormat.png : CompressFormat.jpeg;
      final outputExtension = isPng ? '.png' : '.jpg';

      final targetPath = path.join(
        targetDir.path,
        '${path.basenameWithoutExtension(source.path)}'
        '_${DateTime.now().millisecondsSinceEpoch}$outputExtension',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        quality: _quality,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        format: format,
        // Honour the camera's rotation flag, otherwise portrait photos arrive
        // sideways once the EXIF orientation is stripped by re-encoding.
        autoCorrectionAngle: true,
      );

      if (result == null) return source;

      final compressed = File(result.path);
      final compressedBytes = await compressed.length();

      // Re-encoding can *grow* a file (already-optimised JPEGs, flat PNGs).
      // Keep whichever is smaller and bin the loser.
      if (compressedBytes >= originalBytes) {
        await compressed.delete().catchError((_) => compressed);
        return source;
      }

      return compressed;
    } catch (e) {
      // Never let compression failure block presenting an image.
      print('⚠️ Image compression skipped: $e');
      return source;
    }
  }
}
