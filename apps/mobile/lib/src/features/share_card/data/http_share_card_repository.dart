import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../domain/share_card.dart';

class HttpShareCardRepository implements ShareCardRepository {
  HttpShareCardRepository({required this.baseUri, required this.client});
  final Uri baseUri;
  final http.Client client;
  int _nonce = 0;
  static const _maxBytes = 256 * 1024;
  @override
  Future<String> fetch(String token, ShareCardFormat format) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,64}$').hasMatch(token)) {
      throw const ShareCardFailure(
        'Verify your share link before making an image.',
      );
    }
    // This public asset request never sends the listener's bearer. A unique
    // query and no-cache avoid reusing the endpoint's five-minute CDN cache.
    final uri = baseUri
        .resolve('/api/v1/share/${Uri.encodeComponent(token)}/card')
        .replace(
          queryParameters: {
            'format': format.name,
            '_fresh': '${DateTime.now().microsecondsSinceEpoch}-${_nonce++}',
          },
        );
    final response = await client
        .get(
          uri,
          headers: {
            'Accept': 'image/svg+xml',
            'Cache-Control': 'no-cache, no-store',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      throw const ShareCardFailure(
        'This reading is no longer shared. Verify or publish its link before trying again.',
      );
    }
    if (response.statusCode != 200 ||
        response.bodyBytes.length > _maxBytes ||
        response.headers['content-type']
                ?.split(';')
                .first
                .trim()
                .toLowerCase() !=
            'image/svg+xml') {
      throw const ShareCardFailure(
        'The share image is unavailable. Please try again.',
      );
    }
    final svg = utf8.decode(response.bodyBytes);
    validateShareCardSvg(svg, format);
    return svg;
  }
}

void validateShareCardSvg(String svg, ShareCardFormat format) {
  const invalid = ShareCardFailure(
    'The share image could not be verified. Please try again.',
  );
  if (svg.length > 256 * 1024 ||
      RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(svg)) {
    throw invalid;
  }
  try {
    final root = XmlDocument.parse(svg).rootElement;
    if (root.name.local != 'svg' ||
        root.getAttribute('width') != '${format.width}' ||
        root.getAttribute('height') != '${format.height}' ||
        root.getAttribute('viewBox') !=
            '0 0 ${format.width} ${format.height}') {
      throw invalid;
    }
    // Current contract is self-contained geometry/text. No network images,
    // external fonts, CSS, scripts or foreign document content can be rendered.
    for (final element in [root, ...root.descendants.whereType<XmlElement>()]) {
      if (!{
        'svg',
        'rect',
        'text',
        'tspan',
        'g',
        'path',
        'line',
      }.contains(element.name.local)) {
        throw invalid;
      }
      for (final attribute in element.attributes) {
        if (attribute.name.local.toLowerCase().startsWith('on') ||
            attribute.name.local == 'href' ||
            RegExp(
              r'url\s*\(',
              caseSensitive: false,
            ).hasMatch(attribute.value)) {
          throw invalid;
        }
      }
    }
  } on ShareCardFailure {
    rethrow;
  } catch (_) {
    throw invalid;
  }
}
