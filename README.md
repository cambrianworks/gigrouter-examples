# gigrouter-examples

The gigrouter-examples repository contains:

* Examples of (mostly k3s) user applications
* [Instructions for installing CUDA 12](./cuda-12)
* Functional tools
* System software for the GigRouter

The user applications are focused on k3s simple examples in Python, larger examples ideally in line with common needs, simple CUDA examples that leverage the GPU and a YOLO example that uses Python and Torch libraries which also leverages the GPU.

The examples also include **exercises** to customize the examples, demonstrate features of k3s, illustrate configuration of k3s and work to provide foresight to avoid potential gotchas or surprise resource exhaustion.

The suggested workflow is to:
* Read the k3s overview
* Follow the Python k3s example 1 which builds an http server that supports simple addition
  * This example includes an exercise to add a `multiply` function

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
