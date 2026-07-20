import 'package:permission_handler/permission_handler.dart';

/// Centralised permission requests for everything the Studio needs.
///
/// Each method returns `true` only if the permission ends up granted
/// (including "limited" photo access on iOS 14+, which is enough for
/// picking media).
class PermissionService {
  const PermissionService();

  Future<bool> requestCamera() => _request(Permission.camera);

  Future<bool> requestMicrophone() => _request(Permission.microphone);

  /// Photos / videos library access.
  ///
  /// On Android 13+ this maps to granular media permissions, on iOS to
  /// `NSPhotoLibraryUsageDescription`. `permission_handler`'s `Permission
  /// .photos` already abstracts the platform difference.
  Future<bool> requestPhotos() => _request(Permission.photos);

  Future<bool> requestCameraAndMicrophone() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> _request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    final result = await permission.request();
    return result.isGranted || result.isLimited;
  }

  Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  Future<void> openSettings() => openAppSettings();
}
