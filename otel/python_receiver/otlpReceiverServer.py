from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, Response
import uvicorn
import json
from opentelemetry.proto.collector.metrics.v1.metrics_service_pb2 import ExportMetricsServiceRequest
from google.protobuf.json_format import MessageToJson
import gzip

# Define the receiver class with the process_metrics method.
class OtlpMetricsReceiver:
    def process_metrics(self, binary_data: bytes) -> dict:
        export_request = ExportMetricsServiceRequest()
        export_request.ParseFromString(binary_data)
        json_str = MessageToJson(export_request)
        return json.loads(json_str)


# Simple in-memory connection manager for clients connecting to us
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)


# Create an instance of the receiver that you use in your endpoints.
manager = ConnectionManager()
metrics_receiver = OtlpMetricsReceiver()
app = FastAPI()

# Webserver connection manager
@app.websocket("/ws/metrics")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep the connection alive by receiving messages if any
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@app.post("/v1/metrics")
async def receive_metrics(request: Request):
    binary_body = await request.body()
    # print("Headers:", request.headers)
    # print("Payload length:", len(binary_body))
    # Check for gzip compression and decompress if necessary
    if request.headers.get("content-encoding", "").lower() == "gzip":
        try:
            binary_body = gzip.decompress(binary_body)
            print("Received payload size:", len(binary_body))
        except Exception as err:
            print("Error decompressing gzipped payload:", err)
            return Response(
                content=f"Error decompressing payload: {err}", status_code=400
            )

    try:
        metrics_data = metrics_receiver.process_metrics(binary_body)
    except Exception as e:
        print("Error processing metrics data:", e)
        return Response(content=f"Error processing metrics data: {e}", status_code=400)

    # Broadcast metrics to all connected clients
    json_str = json.dumps(metrics_data)
    print(f"    broadcasting str message size : {len(json_str)}")
    await manager.broadcast(json.dumps(metrics_data))
    return Response(content="OK", status_code=200)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=4444)
