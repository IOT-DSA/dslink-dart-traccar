library dslink.traccar.client;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dslink/utils.dart' show logger;

enum SubscriptionType { device, position }

class TraccarClient {
  static const String _authUrl = 'api/session';
  static final Map<String, TraccarClient> _cache = <String, TraccarClient>{};

  HttpClient _client;

  final String _username;
  final String _password;
  Uri _rootUri;
  List<Cookie> _cookies;

  bool isAuthorized = false;

  factory TraccarClient(String server, String username, String password) =>
      _cache.putIfAbsent('$username@$server',
          () => new TraccarClient._(server, username, password));

  TraccarClient._(String server, this._username, this._password) {
    _rootUri = Uri.parse(server);
    _client = new HttpClient();
  }

  Future<Map<String, dynamic>> authenticate() async {
    var queryParam = { 'email' : _username, 'password' : _password };
    var authUri = _rootUri.replace(path: _authUrl, queryParameters: queryParam);
    HttpClientRequest req;
    HttpClientResponse resp;
    String body;

    print(authUri);
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
      logger.warning('Unable to connect to $authUri', e);
      return { 'success': false, 'message' : 'Error connecting to server' };
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

  Future<List<Map>> get(String path) async {
    String body;
    HttpClientRequest req;
    HttpClientResponse resp;

    var url = _rootUri.replace(path: path);
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

  Stream<Map<String, dynamic>> subscribe(SubscriptionType type, int id) {
    // TODO: Complete
  }
}