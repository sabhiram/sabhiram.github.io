---
title: "Using Python generators in Golang"
categories: Python C Go
tags: python, go, c, development
---

A while back I had written a nifty text fuzzer in python that generates a  deterministic pseudo-random stream of text for anyone willing to listen. The method employed a [`python generator`](https://wiki.python.org/moin/Generators) which would [`yield`]() lines to the caller until it ran out.

Recently, while pondering rewriting the fuzzer using `go`, I came across a thought: what if we could use the best of both worlds?

In theory, our `go` application can invoke the python interpreter using something like `os.Exec(...)`, but that leaves the fate of the generator iteration in python-land, what if we wanted to retain control of the generator from go? In this post, we explore importing a simple python generator using `libpython` and writing minimal wrapper code to be able to iterate the generator from go. While this is probably not all that useful in practice, I found the exercise rather meditative.

The code referenced throughout this post can be found at [this git repo](https://github.com/sabhiram/py-c-go).

This post will broadly cover:
1. Using the [Python/C API](https://docs.python.org/2/c-api/index.html) to wrap the py library in C.
2. Using [cgo](https://golang.org/cmd/cgo/) to wrap the C code and get access to the generator.

### A basic (python) generator

Assume we have a python file (`generator.py`) that includes a `random_generator`:

```python
# File: generator.py
import random

def random_generator(n=100):
    """ generates `n` random values between 0 - 100 (inclusive).
    """
    print "Generator invoked (n==%d)" % (n)
    for i in range(n):
        yield random.randint(0, 100)
```

The above generator yields `n` number of `random.randint()`s from 0-100. The `yield` semantic is used to remember the current offset to the set of values being yielded to the caller. This allows for each successive iteration of the generator (via `.next()` or range-based-access) to return the next value in the set.

```python
# File: example.py
import generator
g = generator.random_generator()
for v in g:
    print "Got random value: %d" % (v)
```

Now we need a way to invoke the above `random_generator()` using the C/Python API. Before we dive into that, a brief foray into `cgo`.

### A little cgo

Below is a simple `go` program that invokes a simple C function (`print_x(int)`):

```golang
// File: simple_c.go
package main

/*
#cgo LDFLAGS:
#cgo CFLAGS: -g -Wall

#include <stdio.h>

void print_x(int x)
{
    printf("X = %d\n", x);
}
*/
import "C"

func main() {
    C.print_x(1)
    C.print_x(2)
    C.print_x(3)
}
```

The `C` import exposes all underlying C functions (standard or linked against explicitly). The comment (or comments) that come directly before the `import "C"` line is referred to as the `preamble` and is treated as a C-header during the compilation of the C code in the program (this is special in cgo).

The next interesting thing to notice is the `#cgo` directive. These are used to set the `CFLAGS`, `CPPFLAGS`, `CXXFLAGS` and `LDFLAGS` as required by the program. Since we do not have any explicit libraries to link (yet), the `LDFLAGS` directive above is left empty.

When the above program is run, we see the three invocations of `printf` resulting in writes to stdout.

```shell
$ go run simple_c.go
X = 1
X = 2
X = 3
```

At this point, have successfully executed a C `printf` invoked from `golang`.

### Embedding the python interpreter

Note: Assuming that we are using Python2.7.

The first modification required to our simple cgo example is to `#include <python2.7/Python.h>`. To do so, we also must tell the linker that we intend to link against the python2.7 libraries. Using the C/Python API also requires the calling code to initialize and cleanup the python interpreter (as well as correctly reference count objects).

```golang
// File: simple_py.go
package main

/*
#cgo LDFLAGS: -lpython2.7
#cgo CFLAGS: -g -Wall

#include <python2.7/Python.h>
*/
import "C"

func main() {
    /*
     *  Initialize and cleanup the python interpreter.
     */
    C.Py_Initialize()
    defer C.Py_Finalize()
}
```

The above program should cleanly exit and compile with no errors (ignore the `unused variable "a"` warning for now).

```shell
$ go run simple_py.go
# command-line-arguments
cgo-gcc-prolog:35:33: warning: unused variable 'a' [-Wunused-variable]
cgo-gcc-prolog:47:33: warning: unused variable 'a' [-Wunused-variable]
```

To recap, we now know how to call C functions from `go`, and we also have linked against `libpython`.

### Importing modules


