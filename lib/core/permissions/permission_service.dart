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

  // NOTE: there is deliberately no `requestPhotos()` here. The gallery
  // flow uses `image_picker`, which delegates to the system's own
  // Photo Picker / gallery app — that picker runs out-of-process and
  // needs no photo-library permission grant at all, on any supported
  // Android or iOS version. Requesting one anyway would only add
  // unnecessary friction for the user.

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
