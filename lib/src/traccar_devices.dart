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
      tmp = parent.parent;
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
      }
    };
  }

  final SubscriptionType subType = SubscriptionType.device;
  int id;
  StreamSubscription _sub;

  TraccarDevice(String path) : super(path) {
    this.serializable = false;
  }

  @override
  onCreated() async {
    await super.onCreated();

    id = provider.getNode('$path/id').value;
    print('Device created: $id');
    if (_sub == null) {
      _sub = client.subscribe(subType, id).listen(onSocketUpdate);
    }
  }

  onSocketUpdate(Map<String, dynamic> data) {
    print('Received data: $data');
  }
}