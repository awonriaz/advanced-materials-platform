from __future__ import annotations

import json

# This is an OPC-UA gateway simulation for an exam-safe environment.
# Production would use asyncua to subscribe to real NodeIds and forward normalized telemetry to /api/v1/iot/process-events.

opcua_tags = {
    "ns=2;s=LineA.Furnace01.Temperature": {"metric_name": "temperature_c", "metric_value": 861.2, "unit": "C"},
    "ns=2;s=LineA.Cutter01.Vibration": {"metric_name": "vibration_mm_s", "metric_value": 4.8, "unit": "mm/s"},
}

normalized = []
for node_id, data in opcua_tags.items():
    normalized.append({
        "source": "OPC-UA",
        "machine_id": node_id.split(".")[-2],
        "line_id": "LINE-A",
        "opcua_node_id": node_id,
        **data,
    })

print(json.dumps({"normalized_opcua_events": normalized}, indent=2))
