import 'dart:io';
import 'package:xml/xml.dart';

void main(List<String> args) async {
  final src = File('assets/icon/kin_arc_final.svg');
  final xml = XmlDocument.parse(await src.readAsString());

  // Remove style defs
  xml.findAllElements('style').forEach((n) => n.parent?.children.remove(n));

  // Map classes to inline styles
  const trustBlue = {'stroke': '#2E86AB', 'stroke-width': '40', 'fill': 'none'};
  const calmTeal = {'stroke': '#A2DEE5', 'stroke-width': '32', 'fill': 'none'};
  const safeGreen = {'fill': '#5FB49C'};

  void applyInline(XmlElement el, Map<String, String> styles) {
    for (final e in styles.entries) {
      el.setAttribute(e.key, e.value);
    }
  }

  for (final el in xml.findAllElements('*')) {
    final klass = el.getAttribute('class');
    if (klass == null) continue;
    switch (klass) {
      case 'trust-blue':
        applyInline(el, trustBlue);
        break;
      case 'calm-teal':
        applyInline(el, calmTeal);
        break;
      case 'safe-green':
        applyInline(el, safeGreen);
        break;
    }
    el.removeAttribute('class');
  }

  final out = File('assets/icon/kin_arc_final.svg');
  await out.writeAsString(xml.toXmlString(pretty: true));
  print('Wrote inline SVG to: ${out.path}');
}
