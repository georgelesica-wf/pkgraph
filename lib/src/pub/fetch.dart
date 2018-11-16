import 'dart:async';
import 'dart:convert' show json;

import 'package:http/http.dart' as http;

import 'package:pkgraph/src/models/package_version.dart';

const defaultSource = 'pub.dartlang.org';
const packageEndpoint = '/api/packages/';

/// Fetch all versions of the given package from the given source
/// (pub server).
///
/// TODO: Consider caching results to allow repeat calls
Future<Iterable<PackageVersion>> fetchPackageVersions(
  String packageName, {
  bool https: true,
  String source: defaultSource,
}) async {
  final url =
      '${https ? 'https' : 'http'}://$source$packageEndpoint$packageName';
  final response = await http.get(url);
  final jsonBody = json.decode(response.body);
  final jsonVersions = jsonBody['versions'] as List<dynamic>;

  final packageVersions = <PackageVersion>[];
  for (int i = 0; i < jsonVersions.length; i++) {
    final jsonVersion = jsonVersions[i] as Map<String, dynamic>;
    final pubspec = jsonVersion['pubspec'] as Map<String, dynamic>;
    packageVersions
        .add(PackageVersion.fromJson(pubspec, ordinal: null, source: source));
  }

  return packageVersions;
}