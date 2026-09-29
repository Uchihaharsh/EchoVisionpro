import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:smart_glasses/providers/camera_providers.dart';

/// Displays the camera preview (Phone Camera or IMX378 USB Smart Glasses) with 100% correct aspect ratio.
class CameraPreviewWidget extends ConsumerWidget {
  final Widget? overlay;

  const CameraPreviewWidget({super.key, this.overlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraStateProvider);

    return Semantics(
      label: '${cameraState.cameraName} View',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. External IMX378 USB-C Camera Preview with Precise Aspect Ratio
          if (cameraState.isInitialized && cameraState.textureId != null)
            Center(
              child: AspectRatio(
                aspectRatio: cameraState.aspectRatio > 0 ? cameraState.aspectRatio : (16 / 9),
                child: Texture(textureId: cameraState.textureId!),
              ),
            )
          // 2. Built-in Smartphone Camera Preview
          else if (cameraState.isInitialized && cameraState.controller != null)
            CameraPreview(cameraState.controller!)
          // 3. Fallback Placeholder
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cameraState.isUsbCamera ? Icons.usb : Icons.camera_alt,
                      color: Colors.white54,
                      size: 80.0,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      cameraState.isInitialized
                          ? cameraState.cameraName
                          : 'Initializing ${cameraState.cameraName}...',
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          
          // Optional overlay (e.g., bounding boxes)
          if (overlay != null) overlay!,

          // Active Camera Source & Status Badge
          Positioned(
            top: 16.0,
            right: 16.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.greenAccent,
                  width: 2.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cameraState.isUsbCamera ? Icons.usb : Icons.camera_alt,
                    size: 16.0,
                    color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.greenAccent,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    cameraState.isUsbCamera ? 'Glasses (IMX378)' : 'Phone Camera',
                    style: TextStyle(
                      color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.greenAccent,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
