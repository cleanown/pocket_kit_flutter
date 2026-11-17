import 'dart:io';

import 'package:image/image.dart' as img;

// Generate splash input sizes without cropping or changing the supplied logo.
// Run before flutter_launcher_icons and flutter_native_splash:create.
void main() {
  final logo = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;
  // Native splash inputs use 4x density: 512 px displays as 128 logical pixels.
  final splash = img.copyResize(
    logo,
    width: 512,
    height: 512,
    interpolation: img.Interpolation.cubic,
  );
  File('assets/images/splash_logo.png').writeAsBytesSync(img.encodePng(splash));

  // Keep the complete logo within Android 12's circular splash safe area.
  final android12 = img.Image(width: 1152, height: 1152, numChannels: 4);
  img.compositeImage(android12, splash, dstX: 320, dstY: 320);
  File('assets/images/splash_logo_android12.png')
      .writeAsBytesSync(img.encodePng(android12));
}
