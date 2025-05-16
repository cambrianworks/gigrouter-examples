
# otlpReceiverServer.py

A simple Python service that relays OpenTelemetry (OTLP) metrics from HTTP/Protobuf into WebSocket text frames (JSON).

This example serves both to understand how to read from OpenTelemetry as well as how to convert the protobuf format to JSON. The example is also serves as a baseline that users can customize to their needs.

It:

- **Receives** OTLP metrics over HTTP/Protobuf at **`POST /v1/metrics`**  
- **Parses** the Protobuf `ExportMetricsServiceRequest` into JSON  
- **Broadcasts** the JSON payload to connected WebSocket clients at **`/ws/metrics`**  
- Supports **gzip**‐compressed payloads  

---

## Features

- HTTP ingestion: `POST /v1/metrics`  
- WebSocket broadcast: `ws://<host>:<port>/ws/metrics`  
- Transparent GZIP decompression  
- Pure Python/FastAPI  

---

## Prerequisites

- **Python 3.8+**  
- **protoc** v3.15.0+ (for generating the `.proto` → `_pb2.py` files)  
- A clone of the [OpenTelemetry proto definitions](https://github.com/open-telemetry/opentelemetry-proto)  
- **websocat** (optional) for reading the JSON output to websocket

Note: Protocol Buffers (or protobufs) use a strictly defined binary format for representing data and are defined in `*.proto` files whereas JSON is simply a human readable string representation that can be more appropriate to certain use cases.
### Setup

- `pip` dependencies: fastapi, uvicorn[standard], protobuf, googleapis-common-protos, opentelemetry-proto

install with
```
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
```

## Run

Note: it is currently hardcoded to be an OTLP Receiver at port 4444, and will rebroadcast the data in JSON format (not protobuf)

First you must configure your OTEL-collector to export to this port

Note: For the default GigRouter install, this file is at: `/etc/gigrouter/k3s/manifests/otel-collector.yaml`

* first add a new Exporter to your otel-collector.yaml:
```bash
exporters:
    otlphttp:
      endpoint: http://<your address here>:4444
```
* then in the same otel-collector.yaml be sure to add your new exporter to the metrics pipeline exports:
```bash
pipelines:
    metrics:
      receivers: [otlp, hostmetrics]
      exporters: [APPEND_TO_EXISTING_LIST, otlphttp]
```
* restart your collector

```bash
kubectl apply -f /etc/gigrouter/k3s/manifests/otel-collector.yaml
kubectl rollout restart deployment otel-collector
```

Now Run your python receiver
```
python otlpReceiverServer.py
```

- **Connect external websocket client (from another terminal session)**
```bash
websocat ws://localhost:4444/ws/metrics # or specify IP address if from other machine
```

Since `websocat` is only for testing, it's not listed in the prerequisites but you can install (if needed) from a bash shell with:

```bash
(VERSION=1.14.0 ARCH=$(uname -m) URL="https://github.com/vi/websocat/releases/download/v${VERSION}/websocat_max.${ARCH}-unknown-linux-musl"; wget -qO websocat "$URL" && chmod +x websocat && sudo mv websocat /usr/local/bin/ && echo "Installed websocat" || echo "Failed to install websocat")
```
