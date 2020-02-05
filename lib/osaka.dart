library osaka;

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// Define Builder
class OsakaTotal implements Builder {
  static const index = r'''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="">

  <!-- iOS meta tags & icons -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="osaka_total_build_step_input_id_package">
  <link rel="apple-touch-icon" href="../../../../../icons/Icon-192.png">

  <title>osaka_total_build_step_input_id_package</title>
</head>
<body>
  <script>
    window.osakaPost = "";
  </script>
  <script src="../../../../../main.dart.js" type="application/javascript"></script>
</body>
</html>''';

  static const tool = r'''import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  var assetManifest = "";
  if (await File('build/web/assets/AssetManifest.json').exists()) {
    var _assetManifest = jsonDecode(
        await File('build/web/assets/AssetManifest.json').readAsString());

    for (var key in _assetManifest.keys) {
      var index = 0;
      for (var value in _assetManifest[key]) {
        _assetManifest[key][index] = '../../../../../../assets/' + value;
        index++;
      }
    }

    assetManifest = jsonEncode(_assetManifest);
  }

  var fontManifest = "";
  if (await File('build/web/assets/FontManifest.json').exists()) {
    var _fontManifest =
        await File('build/web/assets/FontManifest.json').readAsString();

    fontManifest = _fontManifest.replaceAll(
        '"asset":"', '"asset":"../../../../../../assets/');
  }

  if (await Directory('build/web/blog').exists()) {
    var files = await Directory('build/web/blog').list(recursive: true);
    await for (var file in files) {
      if (file.path.endsWith('.html')) {
        if (assetManifest.length > 0) {
          if (await File(p.join(
                  file.parent.uri.toString(), 'assets', 'AssetManifest.json'))
              .exists()) {
            await File(p.join(
                    file.parent.uri.toString(), 'assets', 'AssetManifest.json'))
                .delete();
          }
          var assetManifestJson = await File(p.join(
                  file.parent.uri.toString(), 'assets', 'AssetManifest.json'))
              .create(recursive: true);
          await assetManifestJson.writeAsString(assetManifest);
        }

        if (fontManifest.length > 0) {
          if (await File(p.join(
                  file.parent.uri.toString(), 'assets', 'FontManifest.json'))
              .exists()) {
            await File(p.join(
                    file.parent.uri.toString(), 'assets', 'FontManifest.json'))
                .delete();
          }
          var fontManifestJson = await File(p.join(
                  file.parent.uri.toString(), 'assets', 'FontManifest.json'))
              .create(recursive: true);
          await fontManifestJson.writeAsString(fontManifest);
        }
      }
    }
  }
}''';

  // Match `build_extensions` of `build.yaml`
  @override
  Map<String, List<String>> get buildExtensions {
    return {
      r'$package$': ['lib/posts_build.dart'],
    };
  }

  // Generate code for posts
  @override
  Future<void> build(BuildStep buildStep) async {
    final exp = RegExp('(\\d{4})-(\\d{2})-(\\d{2})-(.*)\\.md');

    var posts = [];

    var building = 'class PostsBuild { static const posts = {';

    await for (final input in buildStep.findAssets(Glob('assets/posts/*'))) {
      if (input.path.endsWith('.md')) {
        // Load post
        var name = Uri.file(input.path).pathSegments.last;
        // (year, month, day)
        final groups = exp.firstMatch(name).groups(<int>[1, 2, 3, 4]).toList();

        if (groups.length == 4) {
          var text = await buildStep.readAsString(input);

          // Add comma if not the first post
          if (!building.endsWith('{')) {
            building += ',';
          }

          building += '\'';
          building += name;
          building += '\':{';

          // Declare post content
          var frontMatter = "";
          var markDown = "";

          // Declare front matter state
          var hasFrontMatterStart = false;
          var parsedFrontMatter = false;

          for (var line in LineSplitter.split(text)) {
            // Clean for analysis
            var lineContent = line.trim();

            if (!parsedFrontMatter) {
              if (!hasFrontMatterStart) {
                if (lineContent.isEmpty) {
                  continue;
                } else {
                  if (lineContent == "---") {
                    hasFrontMatterStart = true;
                  } else {
                    parsedFrontMatter = true;
                  }
                }
              } else {
                if (lineContent == "---") {
                  parsedFrontMatter = true;

                  if (hasFrontMatterStart) {
                    building += '\'frontMatter\':';
                    // Convert front matter to JSON to embed to Dart
                    // TODO: Should convert double quotes to single quotes
                    building += json.encode(loadYaml(frontMatter));
                    building += ',';
                  }
                } else {
                  if (lineContent.isNotEmpty) {
                    // Add new line if not the first line
                    if (frontMatter.isNotEmpty) {
                      frontMatter += '\n';
                    }

                    frontMatter += line;
                  }
                }
              }
            } else {
              if (lineContent.isNotEmpty) {
                // Add new line if not the first line
                if (markDown.isNotEmpty) {
                  markDown += '\n';
                }

                markDown += line;
              }
            }
          }

          if (markDown.isNotEmpty) {
            building += '\'markDown\': r\'\'\'';
            building += markDown;
            building += '\'\'\',';
          }

          building += '}';

          posts.add([name, groups[0], groups[1], groups[2], groups[3]]);
        }
      }
    }

    building += '}; }';

    if (await File('tool/osaka.dart').exists()) {
      await File('tool/osaka.dart').delete();
    }

    final osakaTool = await File('tool/osaka.dart').create(recursive: true);
    await osakaTool.writeAsString(tool);

    if (await Directory('web/blog').exists()) {
      await Directory('web/blog').delete(recursive: true);
    }

    final blog = await Directory('web/blog').create();

    if (await blog.exists()) {
      final packageIndex = index.replaceAll(
          'osaka_total_build_step_input_id_package', buildStep.inputId.package);

      for (final post in posts) {
        final directory = await Directory(
                'web/blog/${post[1]}/${post[2]}/${post[3]}/${post[4]}')
            .create(recursive: true);
        if (await directory.exists()) {
          final file =
              await File(p.join(directory.path, 'index.html')).create();
          if (await file.exists()) {
            await file.writeAsString(packageIndex.replaceAll(
                'window.osakaPost = ""', 'window.osakaPost = "${post[0]}"'));
          }
        }
      }
    }

    return buildStep.writeAsString(
        AssetId(
          buildStep.inputId.package,
          p.join('lib', 'posts_build.dart'),
        ),
        DartFormatter().format(building));
  }
}

// Declare Builder
Builder osakaTotal(BuilderOptions builderOptions) => OsakaTotal();
