import 'dart:convert';
import 'dart:io';

// Decodes a Base64 string into an AAR file under android/app/libs
// Additionally publishes it into a local Maven repository with a minimal POM
// so Gradle can resolve com.transistorsoft:tsbackgroundfetch:4.12.3 offline.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart decode_aar.dart <outputAarPath> <base64Path>');
    exit(64);
  }
  final outPath = args[0];
  final b64Path = args[1];
  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);

  final raw = await File(b64Path).readAsString();
  // 1) Normalize: remove code fences and non-base64 chars
  var s = raw
      .replaceAll('```', '')
      .replaceAll('\r', '')
      .replaceAll('\n', '')
      .trim();
  // 2) Convert URL-safe base64 to standard
  s = s.replaceAll('-', '+').replaceAll('_', '/');
  // 3) Strip any characters not allowed in standard Base64
  s = s.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
  // 4) Drop any existing padding (some sources accidentally inject '=' mid-stream)
  s = s.replaceAll('=', '');
  // 5) Pad to length multiple of 4
  final pad = s.length % 4;
  if (pad != 0) {
    s = s.padRight(s.length + (4 - pad), '=');
  }

  List<int> bytes;
  try {
    bytes = base64.decode(s);
  } catch (e) {
    stderr.writeln('Failed to decode Base64: ' + e.toString());
    exit(65);
  }

  await outFile.writeAsBytes(bytes);
  stdout.writeln('Wrote ${bytes.length} bytes to ' + outFile.path);

  // Also publish to a local Maven repo so Gradle can resolve the module coordinate
  // com.transistorsoft:tsbackgroundfetch:4.12.3
  final repoRoot = Directory('android/local-maven');
  final groupPath = 'com/transistorsoft/tsbackgroundfetch/4.12.3';
  final destDir = Directory(repoRoot.path + '/' + groupPath);
  destDir.createSync(recursive: true);
  final aarOut = File(destDir.path + '/tsbackgroundfetch-4.12.3.aar');
  await aarOut.writeAsBytes(bytes);
  final pom = File(destDir.path + '/tsbackgroundfetch-4.12.3.pom');
  pom.writeAsStringSync('''
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.transistorsoft</groupId>
  <artifactId>tsbackgroundfetch</artifactId>
  <version>4.12.3</version>
  <packaging>aar</packaging>
</project>
''');
  stdout.writeln('Published local Maven artifact at ' + destDir.path);
}
