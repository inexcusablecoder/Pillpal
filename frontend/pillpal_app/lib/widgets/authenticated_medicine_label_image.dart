import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../services/storage_service.dart';

/// Loads `GET /medicines/{id}/label-image` with the stored JWT.
class AuthenticatedMedicineLabelImage extends StatelessWidget {
  const AuthenticatedMedicineLabelImage({
    super.key,
    required this.medicineId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String medicineId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageService>(
      future: StorageService.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _box(const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final token = snap.data!.getToken();
        if (token == null || token.isEmpty) {
          return _box(const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 22));
        }
        final url = AppConstants.medicineLabelImageUrl(medicineId);
        Widget img = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers: {'Authorization': 'Bearer $token'},
          errorBuilder: (_context, _err, _st) {
            return const Icon(Icons.broken_image_outlined, color: AppColors.textMuted, size: 22);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        );
        if (borderRadius != null) {
          img = ClipRRect(borderRadius: borderRadius!, child: img);
        }
        return _box(img);
      },
    );
  }

  Widget _box(Widget child) {
    return SizedBox(
      width: width,
      height: height,
      child: child,
    );
  }
}
