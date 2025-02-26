import 'package:cbj_hub/infrastructure/node_red/node_red_nodes/node_red_visual_node_abstract.dart';

class NodeRedMqttOutNode extends NodeRedVisualNodeAbstract {
  NodeRedMqttOutNode({
    required this.brokerNodeId,
    required this.topic,
    this.qos,
    this.datatype,
    String? name,
  }) : super(
          type: 'mqtt out',
          name: name,
        );

  /// Mqtt broker node id [NodeRedMqttBrokerNode]
  String brokerNodeId;
  String topic;
  String? qos = '2';
  String? datatype = 'auto';

  @override
  String toString() {
    return '''
    {
    "id": "$id",
    "type": "$type",
    "name": "$name",
    "topic": "$topic",
    "qos": "$qos",
    "retain": "",
    "broker": "$brokerNodeId",
    "wires": ${fixWiresForNodeRed()}
  }''';
  }
}
