import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/share_card.dart';
import 'http_share_card_repository.dart';

class SvgShareCardRenderer implements ShareCardRenderer {
  @override
  Future<Uint8List> png(String svg, ShareCardFormat format) async {
    validateShareCardSvg(svg, format);
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    try {
      if (info.size.width != format.width ||
          info.size.height != format.height) {
        throw const ShareCardFailure('The share image has an unexpected size.');
      }
      final image = await info.picture.toImage(format.width, format.height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw const ShareCardFailure('Could not prepare the share image.');
        }
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }
}
