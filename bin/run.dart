library dslink.traccar;

import 'dart:async';

import 'package:dslink/client.dart';

import 'package:dslink_traccar/traccar_nodes.dart';

Future main(List<String> args) async {
  LinkProvider link;
  link = new LinkProvider(args, 'Traccar-', command: 'run', profiles: {
    AddConnection.isType : (String path) => new AddConnection(path, link),
    RemoveConnection.isType : (String path) => new RemoveConnection(path, link),
    RefreshConnection.isType : (String path) => new RefreshConnection(path),
    TraccarNode.isType : (String path) => new TraccarNode(path),
    TraccarPosition.isType : (String path) => new TraccarPosition(path),
    TraccarReport.isType : (String path) => new TraccarReport(path),
    TraccarDevice.isType : (String path) => new TraccarDevice(path)
  }, autoInitialize: false);

  link.init();
  link.addNode('/${AddConnection.pathName}', AddConnection.definition());
  await link.connect();
}