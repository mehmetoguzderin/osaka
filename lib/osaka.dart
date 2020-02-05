library osaka;

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class _PostsBuild {
  final String name;
  final String frontmatter;
  final String markdown;
  final String year;
  final String month;
  final String day;
  final String layout;
  final String title;
  final List<String> categories;
  final List<String> author;

  const _PostsBuild({
    this.name,
    this.frontmatter,
    this.markdown,
    this.year,
    this.month,
    this.day,
    this.layout,
    this.title,
    this.categories,
    this.author,
  });

  @override
  String toString() {
    return '''const _PostsBuild(
  name: r\'\'\'${this.name}\'\'\',
  frontmatter: r\'\'\'${this.frontmatter}\'\'\',
  markdown: r\'\'\'${this.markdown}\'\'\',
  year: r\'\'\'${this.year}\'\'\',
  month: r\'\'\'${this.month}\'\'\',
  day: r\'\'\'${this.day}\'\'\',
  layout: r\'\'\'${this.layout}\'\'\',
  title: r\'\'\'${this.title}\'\'\',
  categories: const [${this.categories.map((e) => 'r\'\'\'' + e + '\'\'\'').join(', ')}],
  author: const [${this.author.map((e) => 'r\'\'\'' + e + '\'\'\'').join(', ')}],
)''';
  }

  static const String postsBuild = r'''class _PostsBuild {
  final String name;
  final String frontmatter;
  final String markdown;
  final String year;
  final String month;
  final String day;
  final String layout;
  final String title;
  final List<String> categories;
  final List<String> author;

  const _PostsBuild({
    this.name,
    this.frontmatter,
    this.markdown,
    this.year,
    this.month,
    this.day,
    this.layout,
    this.title,
    this.categories,
    this.author,
  });
}''';
}

// Define Builder
class OsakaTotal implements Builder {
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

  if (await File('build/web/index_post.html').exists()) {
    await File('build/web/index_post.html').delete();
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
    final index = await File('web/index_post.html').readAsString();

    final exp = RegExp('(\\d{4})-(\\d{2})-(\\d{2})-(.*)\\.md');

    Map<String, _PostsBuild> posts = {};

    await for (final input in buildStep.findAssets(Glob('assets/posts/*'))) {
      var name = Uri.file(input.path).pathSegments.last;
      final groups = exp.firstMatch(name).groups(<int>[1, 2, 3, 4]).toList();
      if (groups.length == 4) {
        var lines = LineSplitter.split(await buildStep.readAsString(input));
        String frontmatter = null;

        var index = 0;
        for (final line in lines) {
          index++;

          if (line.trim() == '---') {
            if (frontmatter == null) {
              frontmatter = '';
            } else {
              break;
            }
          } else {
            if (frontmatter == null) {
              break;
            } else {
              frontmatter += line.trim();
              frontmatter += '\n';
            }
          }
        }

        String markdown = null;

        for (final line in lines.skip(index)) {
          index++;

          if (markdown == null) {
            if (line.trim().length > 0) {
              markdown = line;
              markdown += '\n';
            }
          } else {
            markdown += line.trim();
            markdown += '\n';
          }
        }

        var _frontmatter = loadYaml(frontmatter);

        List<String> categories = [];
        for (final category in _frontmatter['categories']) {
          categories.add(category as String);
        }

        List<String> authors = [];
        for (final author in _frontmatter['author']) {
          authors.add(author as String);
        }

        posts[name] = _PostsBuild(
          name: groups[3],
          frontmatter: frontmatter,
          markdown: markdown,
          year: groups[0],
          month: groups[1],
          day: groups[2],
          layout: _frontmatter['layout'],
          title: _frontmatter['title'],
          categories: categories,
          author: authors,
        );
      }
    }

    String building = _PostsBuild.postsBuild;
    building += '\n';
    building += '\n';
    building +=
        r'''class PostsBuild { static const Map<String, _PostsBuild> posts = {''';

    for (final key in posts.keys.toList().reversed) {
      building += '\n';
      building += 'r\'\'\'${key}\'\'\': ';
      building += posts[key].toString();
      building += ',';
    }
    building += '\n';
    building += r'''}; }''';

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

      for (final post in posts.keys) {
        final directory = await Directory(
                'web/blog/${posts[post].year}/${posts[post].month}/${posts[post].day}/${posts[post].name}')
            .create(recursive: true);
        if (await directory.exists()) {
          final file =
              await File(p.join(directory.path, 'index.html')).create();
          if (await file.exists()) {
            await file.writeAsString(packageIndex.replaceAll(
                '<script id="osaka-post" type="text">osaka_total_build_step_post_name</script>',
                '<script id="osaka-post" type="text">${post}</script>'));
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
