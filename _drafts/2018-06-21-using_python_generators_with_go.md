---
title: "Using Python generators in Golang"
categories: Python C Go
tags: python, go, c, development
---

A while back I had written a nifty text fuzzer in python which generated deterministic pseudo-random command streams for anyone willing to listen. The fuzzer in question would get constructed and queried for a [`generator`](https://wiki.python.org/moin/Generators) which would endlessly [`yield`]() lines for the caller to do with as they saw fit.

Recently, while pondering re-writing the fuzzer using `go`, I came across a stumbling block: what if we could do the best of both? In theory, our `go` application can invoke the python code directly using something like `os.Exec(...)`, but that involves writing a python program that interacts with the fuzzer library. In this post we explore importing a python library using `C` with `libpython` and wrapping the boilerplate-ish `C` code with some `go` code.

While this is probably not all that useful in practice, I found the exercise rather meditative. So here we go!

### Goals

We would like to maintain the advantages of the python generator, while being able to invoke it from golang.

### Method

1. Use the [Python/C API](https://docs.python.org/2/c-api/index.html) to wrap the library in C.
2. Use [cgo](https://golang.org/cmd/cgo/) to wrap the C code and get access to the generator.

### A basic generator

Assume we have a python file (`gen.py`) which implements a generator thusly:

```python
# File: gen.py
import random

def generator(n=100):
    """ generates `n` random values between 0 - 100 (inclusive).
    """
    for i in range(n):
        yield random.randint(0, 100)

```

This can be used like so (from python land):
```python
import gen

if __name__ is "__main__":
    g = gen.generator()
    for v in g:
        print "Got random value: %d" % (v)

```


