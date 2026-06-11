from __future__ import annotations

import json
import os
import time

import paho.mqtt.client as mqtt

lot_id = os.getenv("LOT_ID", "LOT-MQTT-DEMO")
host = os.getenv("MQTT_HOST", "127.0.0.1")
port = int(os.getenv("MQTT_PORT", "1883"))

payload = {
    "lot_id": lot_id,
    "source": "MQTT",
    "machine_id": "FURNACE-01",
    "line_id": "LINE-A",
    "metric_name": "temperature_c",
    "metric_value": 872.5,
    "unit": "C",
    "timestamp": int(time.time()),
}

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.connect(host, port, 60)
client.publish(f"amscp/materials/{lot_id}/telemetry", json.dumps(payload), qos=1)
client.disconnect()
print(json.dumps({"published": True, "topic": f"amscp/materials/{lot_id}/telemetry", "payload": payload}, indent=2))
