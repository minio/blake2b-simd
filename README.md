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


Example performance metrics were generated on  Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz - 6 physical cores, 12 logical cores running Ubuntu GNU/Linux with kernel version 4.4.0-24-generic (vanilla with no optimizations).

```
$ benchcmp old.txt new.txt
benchmark                old ns/op     new ns/op     delta
BenchmarkHash64-12       1481          849           -42.67%
BenchmarkHash128-12      1428          746           -47.76%
BenchmarkHash1K-12       6379          2227          -65.09%
BenchmarkHash8K-12       37219         11714         -68.53%
BenchmarkHash32K-12      140716        35935         -74.46%
BenchmarkHash128K-12     561656        142634        -74.60%

benchmark                old MB/s     new MB/s     speedup
BenchmarkHash64-12       43.20        75.37        1.74x
BenchmarkHash128-12      89.64        171.35       1.91x
BenchmarkHash1K-12       160.52       459.69       2.86x
BenchmarkHash8K-12       220.10       699.32       3.18x
BenchmarkHash32K-12      232.87       911.85       3.92x
BenchmarkHash128K-12     233.37       918.93       3.94x
```

We can see `2-3x` improvement in performance over native Go under varying block sizes.