library osaka;

import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// Define Builder
class Osaka implements Builder {
  // Match `build_extensions` of `build.yaml`
  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      r'$package$': const ['lib/posts_build.dart'],
    };
  }

  // Generate code for posts
  @override
  Future<void> build(BuildStep buildStep) async {
    var building = 'class PostsBuild { static const posts = {';

    await for (final input in buildStep.findAssets(Glob('assets/posts/*'))) {
      if (input.path.endsWith('.md')) {
        // Load post
        var name = Uri.file(input.path).pathSegments.last;
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
              if (lineContent.length == 0) {
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
                if (lineContent.length > 0) {
                  // Add new line if not the first line
                  if (frontMatter.length > 0) {
                    frontMatter += '\n';
                  }

                  frontMatter += line;
                }
              }
            }
          } else {
            if (lineContent.length > 0) {
              // Add new line if not the first line
              if (markDown.length > 0) {
                markDown += '\n';
              }

              markDown += line;
            }
          }
        }

        if (markDown.length > 0) {
          building += '\'markDown\': r\'\'\'';
          building += markDown;
          building += '\'\'\',';
        }

        building += '}';
      }
    }

    building += '}; }';

    return buildStep.writeAsString(
        AssetId(
          buildStep.inputId.package,
          p.join('lib', 'posts_build.dart'),
        ),
        DartFormatter().format(building));
  }
}

// Declare Builder
Builder osaka(BuilderOptions builderOptions) => Osaka();
