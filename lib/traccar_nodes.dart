library dslink.traccar.nodes;

import 'dart:async';
import 'dart:collection';

import 'package:dslink/responder.dart';
import 'package:dslink/client.dart';
import 'package:dslink/nodes.dart';

import 'src/traccar_client.dart';

part 'src/traccar_devices.dart';

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
        'type' : 'string',
        'editor': 'password'
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
    RemoveConnection.pathName : RemoveConnection.definition(),
    RefreshConnection.pathName : RefreshConnection.definition(),
    AddDevice.pathName : AddDevice.definition()
  };

  Future<TraccarClient> get client => _completer.future;
  Completer<TraccarClient> _completer;
  TraccarClient _client;
  Set<int> deviceIds;

  TraccarNode(String path) : super(path) {
    _completer = new Completer<TraccarClient>();
    deviceIds = new Set<int>();
  }

  @override
  onCreated() async {
    var server = getConfig(r'$$tc_server');
    var user = getConfig(r'$$tc_user');
    var pass = getConfig(r'$$tc_pass');

    var refNode = provider.getNode('$path/${RefreshConnection.pathName}');
    if (refNode == null) {
      provider.addNode('$path/${RefreshConnection.pathName}',
          RefreshConnection.definition());
    }

    _client = new TraccarClient(server, user, pass);
    _completer.complete(_client);

    if (!_client.isAuthorized) {
      await _client.authenticate();
    }

    var devices = await _client.get(TraccarDevice.url);
    if (devices.isEmpty) return;

    for (var device in devices) {
      _addDevice(device);
    }
    _client.onNewDevice.listen(_addDevice);
    await _client.connectWebSocket();
  }

  @override
  void onRemoving() {
    _client.close();
  }

  void _addDevice(Map<String, dynamic> device) {
    if (deviceIds.contains(device['id'])) return;
    deviceIds.add(device['id']);
    var devicesNode = provider.getOrCreateNode('$path/devices');
    var devNodePath = devicesNode.path;
    var name = NodeNamer.createName(device['name']);
    provider.addNode('$devNodePath/$name', TraccarDevice.definition(device));

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

class RefreshConnection extends SimpleNode {
  static const String isType = 'refreshConnectionNode';
  static const String pathName = 'Refresh_Connection';
  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Refresh Connection',
    r'$invokable' : 'write',
    r'$params' : [],
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

  RefreshConnection(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map params) async {
    var client = await (parent as TraccarNode).client;
    await client.resetWebsocket();
    return {
      'success' : true,
      'message' : 'Refreshed!'
    };
  }
}

class AddDevice extends SimpleNode {
  static const String isType = 'addDeviceNode';
  static const String pathName = 'Add_Device';
  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Device',
    r'$invokable' : 'write',
    r'$params' : [
      {
        'name' : 'name',
        'type' : 'string',
        'placeholder' : 'Name'
      },
      {
        'name' : 'identifier',
        'type' : 'string',
        'placeholder' : 'identifier'
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
        'default': ''
      }
    ]
  };
  
  AddDevice(String path) : super(path);
  
  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var ret = { 'success': false, 'message': '' };
    if (params['name'] == null || params['name'].isEmpty ||
        params['identifier'] == null || params['identifier'].isEmpty) {
      ret['message'] = 'Name and Identifier are required';
      return ret;
    }

    var data = {
      'id' : -1,
      'name' : params['name'].trim(),
      'uniqueId' : params['identifier'].trim(),
      'status' : '',
      'lastUpdate': null
    };

    var client = await (parent as TraccarNode).client;
    var res = await client.post(TraccarDevice.url, data);
    if  (res != null) {
      ret['success'] = true;
      ret['message'] = 'Success';
    } else {
      ret['message'] = 'Failed to add device.';
    }
    return ret;
  }
}