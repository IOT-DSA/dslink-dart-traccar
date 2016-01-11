library dslink.traccar.client;

import 'dart:async';
import 'dart:io';
import 'dart:collection' show HashMap;
import 'dart:convert';

import 'package:dslink/utils.dart' show logger;

enum SubscriptionType { device, position }

class TraccarClient {
  static const String _authUrl = 'api/session';
  static const String _wsUrl = 'api/socket';
  static final Map<String, TraccarClient> _cache = <String, TraccarClient>{};

  HttpClient _client;

  final String _username;
  final String _password;
  Uri _rootUri;
  List<Cookie> _cookies;
  WebSocket _ws;
  StreamController<Map<String, dynamic>> _newDevices;
  Set<int> _pendingDevices;

  bool isAuthorized = false;
  HashMap<int, StreamController<TraccarUpdate>> subscriptions;
  Stream<Map<String, dynamic>> get onNewDevice => _newDevices.stream;

  factory TraccarClient(String server, String username, String password) =>
      _cache.putIfAbsent('$username@$server',
          () => new TraccarClient._(server, username, password));

  TraccarClient._(String server, this._username, this._password) {
    _rootUri = Uri.parse(server);
    _client = new HttpClient();
    _newDevices = new StreamController<Map<String, dynamic>>();
    _pendingDevices = new Set<int>();
  }

  Future<Map<String, dynamic>> authenticate() async {
    var queryParam = { 'email' : _username, 'password' : _password };
    var authUri = _rootUri.replace(path: _authUrl, queryParameters: queryParam);
    HttpClientRequest req;
    HttpClientResponse resp;
    String body;

    try {
      req = await _client.postUrl(authUri);
      req.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'UTF-8');
      resp = await req.close();
      if (resp.cookies != null && resp.cookies.isNotEmpty) {
        _cookies = resp.cookies.toList(growable: false);
      }

      body = await resp.transform(UTF8.decoder).join();
      logger.info('Response Status: ${resp.statusCode}');
      logger.info('Response Body: $body');
    } on HttpException catch (e) {
      var tmpUrl = authUri.replace(queryParameters: null);
      logger.warning('Unable to connect to $tmpUrl', e);
      return { 'success': false, 'message' : 'Error connecting to server' };
    } on SocketException catch (e) {
      var tmpUrl = authUri.replace(queryParameters: null);
      logger.warning('Unable to connect to $tmpUrl', e);
      return new Future.delayed(new Duration(seconds: 30), () => authenticate());
    }

    Map bodyMap;
    try {
      bodyMap = JSON.decode(body);
    } catch (e) {
      logger.warning('Unable to decode response: $body', e);
      return { 'success' : false, 'message' : 'Invalid respones from server'};
    }

    var ret = { 'success' : false, 'message' : '' };
    if (resp.statusCode == HttpStatus.UNAUTHORIZED) {
      ret['message'] = 'Invalid email or password';
    } else if (resp.statusCode == HttpStatus.OK) {
      ret['success'] = true;
      ret['message'] = 'Success';
      isAuthorized = true;
    } else {
      ret['message'] = 'Unknown error';
    }
    return ret;
  }

  void close() {
    _client.close(force: true);
  }

  Future<List<Map>> get(String path, {Map queryParameters}) async {
    String body;
    HttpClientRequest req;
    HttpClientResponse resp;

    var url = _rootUri.replace(path: path, queryParameters: queryParameters);
    logger.finest('GET request for: $url');
    try {
      req = await _client.getUrl(url);
      req.cookies.addAll(_cookies);
      resp = await req.close();
      body = await resp.transform(UTF8.decoder).join();
    } on HttpException catch (e) {
      logger.warning('Error getting url: $url', e);
      return [];
    }

    try {
      return JSON.decode(body);
    } catch (e) {
      logger.warning('Error decoding response: $body', e);
      return [];
    }
  }

  Future connectWebSocket() async {
    var headers = {
      'Cookie' : _cookies.map((c) => c.toString()).join('; ')
    };
    Uri wsUri;
    if (_rootUri.scheme == 'https') {
      wsUri = _rootUri.replace(scheme: 'wss', path: _wsUrl);
    } else {
      wsUri = _rootUri.replace(scheme: 'ws', path: _wsUrl);
    }
    if (subscriptions == null) {
      subscriptions = new HashMap<int, StreamController<TraccarUpdate>>();
    }
    if (_ws == null || _ws.closeCode != null) {
      try {
        _ws = await WebSocket.connect(wsUri.toString(), headers: headers);
      } on WebSocketException catch (e) {
        logger.warning('Error connecting Websocket: $e');
        logger.finest('Trying to re-authenticate');
        authenticate().then((_) {
          connectWebSocket();
        });
        return;
      } catch (e) {
        logger.warning('Error connecting websocket: $e');
        new Future.delayed(new Duration(seconds: 30), () {
          connectWebSocket();
        });
        return;
      }
      _ws.listen(_websocketMessage, cancelOnError: false, onError: (e) {
        logger.warning('Websocket error: $e');
      }, onDone: () {
        logger.finest('Websocket Close: ${_ws.closeCode} - ${_ws.closeReason}');
        connectWebSocket();
      });
    }
  }

  void _websocketMessage(dynamic message) {
    var msg = {};
    logger.finest('Websocket received: $message');
    try {
      msg = JSON.decode(message);
    } catch (e) {
      logger.warning('Websocket Error: Unable to decode message: $message', e);
      return;
    }
    if (msg.containsKey('positions')) {
      for (var posInfo in msg['positions']) {
        var devId = posInfo['deviceId'];
        if (!subscriptions.containsKey(devId)) {
          _pendingDevices.add(devId);
        }
        var subscription =
            subscriptions.putIfAbsent(devId, () => new StreamController<TraccarUpdate>());
        var update = new TraccarUpdate(SubscriptionType.position, posInfo);
        subscription.add(update);
      }
    } else if (msg.containsKey('devices')) {
      for (var devInfo in msg['devices']) {
        bool newDev = false;
        var devId = devInfo['id'];
        if (!subscriptions.containsKey(devId) || _pendingDevices.contains(devId)) {
          newDev = true;
        }
        var subscription =
            subscriptions.putIfAbsent(devId, () => new StreamController<TraccarUpdate>());
        var update = new TraccarUpdate(SubscriptionType.device, devInfo);
        if (newDev) {
          _newDevices.add(devInfo);
          _pendingDevices.remove(devId);
        }
          subscription.add(update);
      }
    } else {
      logger.info('Websocket unknown message type: $msg');
    }
  }

  Stream<TraccarUpdate> subscribe(SubscriptionType type, int id) {
    subscriptions.putIfAbsent(id, () => new StreamController<TraccarUpdate>());
    return subscriptions[id].stream;
  }
}

class TraccarUpdate {
  SubscriptionType type;
  Map<String, dynamic> data;
  TraccarUpdate(this.type, this.data);
}