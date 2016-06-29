BLAKE2b-SIMD
============

Pure Go implementation of BLAKE2b using SIMD optimizations.

Introduction
------------

This package is based on the pure go [BLAKE2b](https://github.com/dchest/blake2b) implementation of Dmitry Chestnykh and merges it with the (`cgo` dependent) SSE optimized [BLAKE2](https://github.com/codahale/blake2) implementation (which in turn is based on [official implementation](https://github.com/BLAKE2/BLAKE2). It does so by using [Go's Assembler](https://golang.org/doc/asm) for amd64 architectures with a fallback for other architectures.

It gives roughly a 3x performance improvement over the non-optimized go version.

Benchmarks
----------

| Dura          |  1 GB |
| ------------- |:-----:|
| blake2b-SIMD  | 1.59s |
| blake2b       | 4.66s |

Here the results after optimization.
```
benchmark                old ns/op     new ns/op     delta
BenchmarkHash64-4        742           411           -44.61%
BenchmarkHash128-4       681           346           -49.19%
BenchmarkWrite1K-4       4239          1497          -64.69%
BenchmarkWrite8K-4       33633         11514         -65.77%
BenchmarkWrite32K-4      134091        45947         -65.73%
BenchmarkWrite128K-4     537976        183643        -65.86%

benchmark                old MB/s     new MB/s     speedup
BenchmarkHash64-4        86.18        155.51       1.80x
BenchmarkHash128-4       187.96       369.10       1.96x
BenchmarkWrite1K-4       241.55       683.87       2.83x
BenchmarkWrite8K-4       3897.06      11383.41     2.92x
BenchmarkWrite32K-4      977.48       2852.63      2.92x
BenchmarkWrite128K-4     243.64       713.73       2.93x
```