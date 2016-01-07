part of dslink.traccar.nodes;

abstract class TraccarChild extends SimpleNode {
  TraccarClient client;
  SubscriptionType get subType;

  TraccarChild(String path) : super(path) {
    serializable = false;
  }

  @override
  onCreated() async {
    var tmp = parent;
    while (tmp is! TraccarNode) {
      tmp = tmp.parent;
    }
    client = await (tmp as TraccarNode).client;
  }
}

class TraccarDevice extends TraccarChild {
  static const String isType = 'traccarDeviceNode';
  static const String url = '/api/devices';
  static Map<String, dynamic> definition(Map data) {
    var status = data['status'] == 'online';
    return {
      r'$is' : isType,
      'id' : {
        r'$name' : 'Id',
        r'$type' : 'int',
        r'?value' : data['id']
      },
      'uniqueId' : {
        r'$name' : 'Unique Id',
        r'$type' : 'string',
        r'?value' : data['uniqueId']
      },
      'online' : {
        r'$type' : 'bool',
        r'?value' : status
      },
      'lastUpdate' : {
        r'$name' : 'Last Update',
        r'$type' : 'string',
        r'?value' : data['lastUpdate']
      },
      'positionId' : {
        r'$name' : 'Position Id',
        r'$type' : 'int',
        r'?value' : data['positionId']
      },
      'dataId' : {
        r'$name' : 'Data Id',
        r'$type' : 'int',
        r'?value' : data['dataId']
      },
      'position' : TraccarPosition.definition(),
      TraccarReport.pathName : TraccarReport.definition(data['id'])
    };
  }

  final SubscriptionType subType = SubscriptionType.device;
  int id;
  StreamSubscription _sub;
  TraccarPosition _posNode;

  TraccarDevice(String path) : super(path) {
    this.serializable = false;
  }

  @override
  onCreated() async {
    await super.onCreated();

    id = provider.getNode('$path/id').value;
    if (_sub == null) {
      var tmp = provider.getNode('$path/position');
      if (tmp != null && tmp is TraccarPosition) {
        _posNode = tmp;
      }
      _sub = client.subscribe(subType, id).listen(onSocketUpdate);
    }
  }

  onSocketUpdate(TraccarUpdate update) {
    var data = update.data;
    if (update.type == SubscriptionType.device) {
      var isOnline = data['status'] == 'online';
      provider.updateValue('$path/online', isOnline);
      provider.updateValue('$path/uniqueId', data['uniqueId']);
      provider.updateValue('$path/lastUpdate', data['lastUpdate']);
      provider.updateValue('$path/positionId', data['positionId']);
    } else if (update.type == SubscriptionType.position) {
      _posNode.update(update.data);
    }
  }
}

class TraccarPosition extends TraccarChild {
  static const String isType = 'traccarPosition';
  static Map<String, dynamic> definition() {
    return {
      r'$is' : isType,
      'fixTime' : {
        r'$name' : 'Fix Time',
        r'$type' : 'string',
        r'?value' : ''
      },
      'latitude' : {
        r'$type' : 'number',
        r'?value' : 0.0
      },
      'longitude' : {
        r'$type' : 'number',
        r'?value' : 0.0
      },
      'location' : {
        r'$type' : 'map',
        r'?value': { 'lat': 0.0, 'lng': 0.0},
        r'@geo': true
      },
      'outdated' : {
        r'$type' : 'bool',
        r'?value': true
      },
      'valid' : {
        r'$type' : 'bool',
        r'?value' : true
      },
      'altitude' : {
        r'$type' : 'number',
        r'?value': 0.0
      },
      'speed' : {
        r'$type' : 'number',
        r'?value' : 0.0
      },
      'course' : {
        r'$type' : 'number',
        r'?value': 0.0
      },
      'address' : {
        r'$type' : 'string',
        r'?value': ''
      },
      'deviceTime' : {
        r'$name' : 'Device Time',
        r'$type' : 'string',
        r'?value' : ''
      },
      'id' : {
        r'$type' : 'int',
        r'?value' : 0
      },
      'protocol' : {
        r'$type' : 'string',
        r'?value': ''
      },
      'deviceId' : {
        r'$name' : 'Device Id',
        r'$type' : 'int',
        r'?value' : 0
      }
    };
  }

  final SubscriptionType subType = SubscriptionType.position;

  TraccarPosition(String path) : super(path);

  void update(Map<String, dynamic> data) {
    data.forEach((String key, dynamic value) {
      if (data[key] != null && key != 'attributes') {
        var nd = provider.getNode('$path/$key');
        if (nd == null) {
          nd = provider.getOrCreateNode('$path/$key');
          nd.configs[r'$type'] = 'string';
        }
        nd.updateValue(value);
      }
      if (data[key] != null && key == 'attributes') {
        var attr = data['attributes'] as Map;
        attr.forEach((atKey, atVal) {
          var nd = provider.getOrCreateNode('$path/$atKey');
          nd.configs[r'$type'] = 'string';
          nd.updateValue(atVal);
        });
      }
    });

    if (data['latitude'] != null && data['longitude'] != null) {
      var loc = { 'lat': data['latitude'], 'lng': data['longitude']};
      provider.updateValue('$path/location', loc);
    }
  }
}

class TraccarReport extends TraccarChild {
  static const String url = 'api/positions';
  static const String isType = 'traccarReportNode';
  static const String pathName = 'Traccar_Report';
  static Map<String, dynamic> definition(int id) => {
    r'$is' : isType,
    r'$$dev_id' : id,
    r'$name' : 'Get History',
    r'$invokable' : 'write',
    r'$result' : 'table',
    r'$params' : [
      {
        'name' : 'dateRange',
        'type' : 'string',
        'editor' : 'daterange'
      }
    ],
    r'$columns' : [
      {
        'name' : 'address',
        'type' : 'string'
      },
      {
        'name' : 'altitude',
        'type': 'num'
      },
      {
        'name' : 'attributes',
        'type' : 'map'
      },
      {
        'name' : 'course',
        'type' : 'num'
      },
      {
        'name' : 'deviceTime',
        'type' : 'num'
      },
      {
        'name': 'latitude',
        'type' : 'num'
      },
      {
        'name' : 'longitude',
        'type' : 'num'
      },
      {
        'name' : 'speed',
        'type' : 'num'
      },
      {
        'name' : 'valid',
        'type' : 'bool'
      }
    ]
  };

  SubscriptionType subType = SubscriptionType.device;

  TraccarReport(String path) : super(path);

  @override
  Future onInvoke(Map<String, dynamic> params) async {
    if (params['dateRange'] == null || params['dateRange'].isEmpty) {
      return null;
    }

    var id = getConfig(r'$$dev_id');
    var dates = params['dateRange'].split('/');
    var queryParams = {
      'deviceId' : '$id',
      'from' : '${dates[0]}Z',
      'to' : '${dates[1]}Z'
    };

    var results = await client.get(url, queryParameters: queryParams);
    var r = [];
    for (Map res in results) {
      var row = [
        res['address'],
        res['altitude'],
        res['attributes'],
        res['course'],
        res['deviceTime'],
        res['latitude'],
        res['longitude'],
        res['speed'],
        res['valid']
      ];
      r.add(row);
    }
    return r;
  }
}