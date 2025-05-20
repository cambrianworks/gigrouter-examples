# gigrouter-examples

This repository provides a collection of examples and tools for the **GigRouter** platform. The examples span various technologies used with GigRouter, including containerized services, telemetry pipelines, and GPU support.

## Getting Started

To use these examples on a GigRouter device with the default Linux configuration:

```bash
ssh gigrouter@GIGROUTER_HOSTNAME
git clone https://github.com/cambrianworks/gigrouter-examples.git
```

## Examples

This repository includes:

- [Example k3s applications](./K3S-EXAMPLES.md): Python-based examples demonstrating HTTP services, persistent volumes, inter-service communication, and Docker-to-k3s image workflows.
- [Python OTLP Receiver](./otel/python_receiver/README.md): A FastAPI-based server that receives OpenTelemetry metrics, converts them to JSON and streams the output to a websocket.
- [CUDA 12 Support](./cuda-12/README.md): Instructions for installing and enabling CUDA 12 support on supported GigRouter devices.

## License

Licensed under either of

 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT)

at your option.

### Contributing

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
