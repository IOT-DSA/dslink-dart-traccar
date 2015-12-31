library dslink.traccar;

import 'dart:async';

import 'package:dslink/client.dart';

import 'package:dslink_traccar/traccar_nodes.dart';

Future main(List<String> args) async {
  LinkProvider link;
  link = new LinkProvider(args, 'Traccar-', command: 'run', profiles: {
    AddConnection.isType : (String path) => new AddConnection(path, link),
    TraccarNode.isType : (String path) => new TraccarNode(path),
  });

  link.addNode('/${AddConnection.pathName}', AddConnection.definition());
  link.init();
  await link.connect();
}