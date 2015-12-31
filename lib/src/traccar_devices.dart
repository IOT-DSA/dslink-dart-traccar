part of dslink.traccar.nodes;

class TraccarDevice extends SimpleNode {
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

  TraccarDevice(String path) : super(path) {
    this.serializable = false;
  }
}