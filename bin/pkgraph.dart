import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'package:pkgraph/src/constants.dart';
import 'package:pkgraph/src/cypher/author.dart';
import 'package:pkgraph/src/cypher/package.dart';
import 'package:pkgraph/src/database/database.dart';
import 'package:pkgraph/src/database/query.dart';
import 'package:pkgraph/src/pub/cache.dart';
import 'package:pkgraph/src/pub/fetch.dart';

final _logger = Logger('pkgraph.dart');

Future<void> main(List<String> args) async {
  Logger.root.onRecord.listen((record) {
    stderr.writeln(record);
  });

  final argParser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Display help',
      negatable: false,
    )
    ..addFlag(
      'local',
      help: 'Treat package names as local paths',
      defaultsTo: false,
      negatable: false,
    )
    ..addOption(
      'neo4j-host',
      help: 'Neo4j host',
      defaultsTo: defaultHost,
      callback: (value) {
        // TODO: Remove once we honor this
        if (value != defaultHost) {
          throw ArgumentError('neo4j-host is not yet implemented');
        }
      },
    )
    ..addFlag(
      'neo4j-https',
      help: 'Use HTTPS to connect to Neo4j',
      defaultsTo: false,
      callback: (value) {
        // TODO: Remove once we honor this
        if (value != false) {
          throw ArgumentError('neo4j-https is not yet implemented');
        }
      },
      negatable: false,
    )
    ..addOption(
      'neo4j-port',
      help: 'Neo4j port',
      defaultsTo: defaultPort.toString(),
      callback: (value) {
        final parsedValue = int.tryParse(value);
        if (parsedValue == null || parsedValue < 1) {
          throw ArgumentError.value(
            value,
            'neo4j-port',
            'A positive integer is required',
          );
        }
        // TODO: Remove once we honor this
        if (value != defaultPort.toString()) {
          throw ArgumentError('neo4j-port is not yet implemented');
        }
      },
    )
    ..addOption(
      'source',
      abbr: 's',
      help: 'Package source (pub server)',
      defaultsTo: defaultSource,
    );
  final argResults = argParser.parse(args);

  if (argResults['help']) {
    print('usage: pkgraph [options] <package names>\n');
    print(argParser.usage);
    print('');
    print('Examples:\n');
    print('Load the graph for the "foo" package');
    print('  pkgraph foo\n');
    print('Load the graph for the "bar" package from pub.mycompany.com');
    print('  pkgraph -s https://pub.mycompany.com bar\n');
    print('Load the graph for the "foo" and "bar" packages');
    print('  pkgraph foo bar\n');
    exit(0);
  }

  // Extract

  // TODO: Remove after we handle special paths, this is just a quick hack
  if (argResults['local']) {
    argResults.rest.forEach((packagePath) {
      if (packagePath.endsWith('.')) {
        throw ArgumentError.value(
            packagePath, 'package path', 'Cannot use "." or ".."');
      }
    });
  }

  for (final packageNameOrPath in argResults.rest) {
    await populatePackagesCache(
      packageNameOrPath,
      isLocalPackage: argResults['local'],
      source: argResults['source'],
    );
  }

  // Load

  final database = Database();
  final constraintsQuery = Query()
    ..add(authorConstraintStatement())
    ..add(sourceConstraintStatement());
  await database.commit(constraintsQuery);

  // Insert packages
  for (final packageVersion in defaultCache.all()) {
    _logger.info('loading versions for $packageVersion');
    final packageQuery = Query()..add(packageVersionStatement(packageVersion));
    await database.commit(packageQuery);
  }

  // Insert authors
  for (final packageVersion in defaultCache.all()) {
    _logger.info('loading authors for $packageVersion');
    final packageQuery = Query()
      ..addAll(packageAuthorStatements(packageVersion));
    await database.commit(packageQuery);
  }

  // Insert dependency relationships
  for (final packageVersion in defaultCache.all()) {
    _logger.info('loading dependencies for $packageVersion');
    final dependencyQuery = Query()
      ..addAll(packageDependenciesStatements(packageVersion));
    await database.commit(dependencyQuery);
  }

  exit(0);
}
