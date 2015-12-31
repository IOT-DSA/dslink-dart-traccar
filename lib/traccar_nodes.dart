library dslink.traccar.nodes;

import 'dart:async';

import 'package:dslink/responder.dart';
import 'package:dslink/client.dart';

import 'src/traccar_client.dart';

class AddConnection extends SimpleNode {
  static const String isType = 'addConnectionNode';
  static const String pathName = 'Add_Connection';
  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Connection',
    r'$invokable' : 'write',
    r'$result' : 'values',
    r'$params' : [
      {
        'name' : 'name',
        'type' : 'string',
        'placeholder' : 'Connection Name'
      },
      {
        'name' : 'address',
        'type' : 'string',
        'placeholder' : 'http://traccar.yourserver.com:8080'
      },
      {
        'name' : 'email',
        'type' : 'string',
        'placeholder' : 'your@email.com'
      },
      {
        'name' : 'password',
        'type' : 'password'
      }
    ],
    r'$columns' : [
      {
        'name' : 'success',
        'type' : 'bool',
        'default' : false
      },
      {
        'name' : 'message',
        'type' : 'string',
        'default' : ''
      }
    ]
  };

  final LinkProvider link;

  AddConnection(String path, this.link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    if (params['address'] == null || params['address'].isEmpty ||
    params['email'] == null || params['email'].isEmpty ||
    params['password'] == null || params['password'].isEmpty) {
      return {
        'success' : false,
        'message' : 'Address, Username and Password are required'
      };
    }

    var client = new TraccarClient(
        params['address'],
        params['email'],
        params['password']);

    var ret = await client.authenticate();
    if (ret['success']) {
      provider.addNode('/${params['name']}', TraccarNode.definition(params));
      link.save();
    }

    return ret;
  }
}

class TraccarNode extends SimpleNode {
  static const String isType = 'traccarNode';
  static Map<String, dynamic> definition(Map params) => {
    r'$is' : isType,
    r'$$tc_server' : params['address'],
    r'$$tc_user' : params['email'],
    r'$$tc_pass' : params['password'],
    RemoveConnection.pathName : RemoveConnection.definition()
  };

  TraccarClient client;
  TraccarNode(String path) : super(path);

  @override
  void onCreated() {
    var server = getConfig(r'$$tc_server');
    var user = getConfig(r'$$tc_user');
    var pass = getConfig(r'$$tc_pass');

    client = new TraccarClient(server, user, pass);

    // TODO: Query devices
  }

  @override
  void onRemoving() {
    client.close();
  }
}

class RemoveConnection extends SimpleNode {
  static const String isType = 'removeConnectionNode';
  static const String pathName = 'Remove_Connection';
  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Connection',
    r'$invokable' : 'write',
    r'$params' : [],
    r'$columns' : []
  };

  LinkProvider link;

  RemoveConnection(String path, this.link) : super(path);

  @override
  onInvoke(Map params) {
    provider.removeNode(parent.path);
    link.save();
  }
}