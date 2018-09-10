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

### Importing (python) modules (from go)

In order to use any python module, the module needs to be loaded into the interpreter. This is typically done in python programs using the `import <module>` statement. `libpython` exposes a method `PyImport_ImportModule(<name>)` which will import modules by `<name>` that exist in the `PYTHONPATH`. Since this is a C method, it does not return a typical `err error`, instead it returns `null -> nil` when the module is not found.

To import the module specified by the file `generator.py`, all we need to do is invoke the `PyImport_ImportModule` method taking care to correctly convert types so the C-library is happy. If this fails, make sure that `generator.py` can be found in the `PYTHONPATH` set in the current environment.

```golang
    module := C.PyImport_ImportModule(C.CString("generator"))
    if unsafe.Pointer(module) == nil {
        fmt.Printf("Unable to import `generator.py`\n")
        os.Exit(1)
    }
```

### Grabbing functions from modules

The above code gets us a reference to the `generator` module and verifies that it is valid.  Next, we define a small wrapper to call the desired function within the imported module. This needs to be implemented as a C wrapper as the `PyObject_CallMethod` is variadic in C, requiring the go code to know the argument list ahead of time.

```c++
PyObject*
call_method_wrapper(PyObject *module, char *method)
{
    return PyObject_CallMethod(module, method, NULL);
}
```

Notice that `PyObject_CallMethod` above does not invoke the `method` with any arguments (hence the NULL as parameter #3). All this does is return a opaque `PyObject*` that represents the return value of the `method`. Calling this from `go` becomes fairly straightforward:

```golang
    gen := C.call_method_wrapper(module, C.CString("random_generator"))
    if gen == nil {
        fmt.Printf("Fatal error: generator is null!\n")
        os.Exit(1)
    }
```

`gen` here is a `unsafe.Pointer` in the go realm and a `PyObject*` that points to an instance of a generator in the `C` world.  Now we can yield values from it until the generator is empty.

Now for the prestige:

```golang
    for l := C.PyIter_Next(gen); unsafe.Pointer(l) != nil; l = C.PyIter_Next(gen) {
        fmt.Printf("Next random number: %d\n", C.PyInt_AsLong(l))
    }
```

`C.PyIter_Next(gen)` is identical to calling `gen.next()` in python to grab the next value from the generator. In order to detect the end of the generator, we simply test the next value against nil.

Since we know the type of value being generated, we can convert the opaque `PyObject*` into an appropriate type (for example with `C.PyInt_AsLong(l)`).

### Conclusion

TODO