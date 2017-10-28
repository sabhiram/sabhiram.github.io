---
title: "Go Function Tracing, Part I"
categories: Go
tags: Go
enableChat: true
---

This is **Part I** of a two-part post on Function Tracing in `Go`. [`Part II`]({% post_url 2015-01-29-golang_trace_fns_part_2 %}) is now online!

Google's `Go` is pretty cool, and fairly fast. A few weeks ago, I finally got around to messing with it. I wrote a couple of simple library functions, and decided that I wanted to build a small lib to trace functions in golang.

The following is an attempt to document my previously stated journey. Be warned, I have only been `Go`ing for the better part of the week.

### Some code

Say we have the following code in file *foo.go*:
{% highlight go %}
package main
import "fmt"

func bar(i int) bool {
    fmt.Printf("Entering bar(%d)\n", i)
    return foo(i)
}

func foo(i int) bool {
    fmt.Printf("Entering foo(%d)\n", i)
    if i > 0 {
        bar(i - 1)
        return false
    }
    return true
}

func main() {
    fmt.Printf("Entering main\n")
    foo(1)
}
{% endhighlight %}

Running the code above with `go run foo.go` would produce something eerily similar to this:
{% highlight sh %}
$ go run foo.go
Entering main
Entering foo(1)
Entering bar(0)
Entering foo(0)
{% endhighlight %}

The above code just prints function names on entry (how boring). What if we also wanted to log the function exit? What if we wanted to visualize the nesting of calls?

### Track Function Enter / Exit (... easily)

Clearly, the naive approach here would be to just tag the **Enter** of a function on function entry (as we did), and then tag the **Exit** before any branches which invoke a return. Even thinking about that makes me feel icky.

Thankfully `Go` provides us with this nifty [`defer statement`](https://golang.org/ref/spec#Defer_statements), which we just might have to abuse a little.

From the documentation for `defer`:

{% include plugins/quote.html start=true %}
Each time a <b>defer</b> statement executes, the function value and parameters to the call are evaluated as usual and saved anew but the actual function is not invoked. Instead, deferred functions are invoked immediately before the surrounding function returns, in the reverse order they were deferred
{% include plugins/quote.html %}

So if we `defer` something immediately after we enter a function, then `Go` will invoke said deferred statement once the function we are executing returns. This is really cool! Without this, we would have to cover every returning branch of code with the exit message.

Now the same code, enriched with the power of `defer`:
{% highlight go %}
package main
import "fmt"

func bar(i int) bool {
    fmt.Printf("Entering bar(%d)\n", i)
    defer fmt.Printf("Exiting bar(%d)\n", i)
    return foo(i)
}

func foo(i int) bool {
    fmt.Printf("Entering foo(%d)\n", i)
    defer fmt.Printf("Exiting foo(%d)\n", i)
    if i > 0 {
        bar(i - 1)
        return false
    }
    return true
}

func main() {
    fmt.Printf("Entering main()\n")
    defer fmt.Printf("Exiting main()\n")
    foo(1)
}
{% endhighlight %}

Now `go run foo.go` produces:
{% highlight sh %}
$ go run foo.go
Entering main()
Entering foo(1)
Entering bar(0)
Entering foo(0)
Exiting foo(0)
Exiting bar(0)
Exiting foo(1)
Exiting main()
{% endhighlight %}

Great! We avoided having to print an exit statement for each branch which returned from the function. Wouldn't it be nice if we did not have to explicitly name the function in our `fmt.Printf()` statements?

### Extracting Function Names (at runtime)

`Go` includes a package [`runtime`](http://golang.org/pkg/runtime/) which will allow us to interact with `Go`'s runtime system. We will use this to figure out the function we are trying to trace by walking the current function stack.

{% highlight go %}
func getFnName() string {
    // Skip this function, and fetch the PC and file for its parent
    pc, _, _, _ := runtime.Caller(1)
    // Retrieve a Function object this functions parent
    functionObject := runtime.FuncForPC(pc)
    // Regex to extract just the function name (and not the module path)
    extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
    return extractFnName.ReplaceAllString(functionObject.Name(), "$1")
}
{% endhighlight %}

The above code also uses the [`regexp`](http://golang.org/pkg/regexp/) package. Note that we pass `1` to `runtime.Caller()`, this is done to skip the current function's program counter. You can read all about the [`runtime.Caller()`](http://golang.org/pkg/runtime/#Caller) function.

After that, we fetch the [`Func object`](http://golang.org/pkg/runtime/#Func) by means of the `FuncForPC()` method. A `Func` object contains finer details about the function pointed to by the appropriate `pc`. Finally, since `Func.Name()` returns a decorated name, we do some parsing to fetch just the parent's "name" as we defined it.

We also probably don't want a bunch of `fmt.Printf(getFunctionName())` statements littering our code, so lets write little nifty `_enter()` and `_exit()` functions. Here is an updated *foo.go*:

{% highlight go %}
package main

import (
    "fmt"
    "runtime"
    "regexp"
)

// Trace Functions
func _enter() {
    // Skip this function, and fetch the PC and file for its parent
    pc, _, _, _ := runtime.Caller(1)
    // Retrieve a Function object this functions parent
    functionObject := runtime.FuncForPC(pc)
    // Regex to extract just the function name (and not the module path)
    extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
    fnName := extractFnName.ReplaceAllString(functionObject.Name(), "$1")
    fmt.Printf("Entering %s\n", fnName)
}

func _exit() {
    // Skip this function, and fetch the PC and file for its parent
    pc, _, _, _ := runtime.Caller(1)
    // Retrieve a Function object this functions parent
    functionObject := runtime.FuncForPC(pc)
    // Regex to extract just the function name (and not the module path)
    extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
    fnName := extractFnName.ReplaceAllString(functionObject.Name(), "$1")
    fmt.Printf("Exiting  %s\n", fnName)
}

// Functions we wish to trace
func bar(i int) bool {
    _enter()
    defer _exit()
    return foo(i)
}

func foo(i int) bool {
    _enter()
    defer _exit()
    if i > 0 {
        bar(i - 1)
        return false
    }
    return true
}

func main() {
    _enter()
    defer _exit()
    foo(1)
}
{% endhighlight %}

Looking better, so now running `go run foo.go` produces:
{% highlight sh %}
$ go run foo.go
Entering main
Entering foo
Entering bar
Entering foo
Exiting  foo
Exiting  bar
Exiting  foo
Exiting  main
{% endhighlight %}

Seems like we lost the parameter logging, we will re-visit that later. Also, being the keen reader, and disciplined coder you are, the copy-pasted section in `_enter()` and `_exit()` is probably irking you. Good, we are on the same page.

One option to remedy the above issue is to invoke another helper function to simply fetch the caller's caller's name (change the "skip" in `runtime.Caller()` from `1` to `2`), another option is explored below.

### One* for the price of Two

So now we have this code block in every function we wish to trace:
{% highlight go %}
_enter()
defer _exit()
{% endhighlight %}

We could move them to the same line by simply adding a `;` between them to tell `Go` that these are independent statements.
{% highlight go %}
_enter(); defer _exit()
{% endhighlight %}

Ideally, we only invoke the `runtime.Caller()` method once per function being traced. Currently it is done twice (once for `_enter()` and once for `_exit()`). We also would like to express the trace function as a single statement.

What if the `_enter()` function, figured out the function being traced, and returned said function name to the `_exit()` function? Ignoring the changes in the function signature, the usage would become something like this:
{% highlight go %}
fn := _enter()
defer _exit(fn)
{% endhighlight %}

This only ameliorates the duplicate code issue, we still have two statements (arguably more complicated than before).

Lets re-visit the `defer` statement. The excerpt for `defer`, tells us that any arguments, to any functions which are being deferred, will be computed at the time of "deferring" and not when the function is eventually executed. This simplifies the above code to:
{% highlight go %}
defer _exit(_enter())
{% endhighlight %}

Putting it all together, *foo.go* should look like this (note that we made the function finding code more readable as well):
{% highlight go %}
package main

import (
    "fmt"
    "runtime"
    "regexp"
)

// Regex to extract just the function name (and not the module path)
var RE_stripFnPreamble = regexp.MustCompile(`^.*\.(.*)$`)

// Trace Functions
func _enter() string {
    fnName := "<unknown>"
    // Skip this function, and fetch the PC and file for its parent
    pc, _, _, ok := runtime.Caller(1)
    if ok {
        fnName = RE_stripFnPreamble.ReplaceAllString(runtime.FuncForPC(pc).Name(), "$1")
    }

    fmt.Printf("Entering %s\n", fnName)
    return fnName
}

func _exit(s string) {
    fmt.Printf("Exiting  %s\n", s)
}

// Functions we wish to trace
func bar(i int) bool {
    defer _exit(_enter())
    return foo(i)
}

func foo(i int) bool {
    defer _exit(_enter())
    if i > 0 {
        bar(i - 1)
        return false
    }
    return true
}

func main() {
    defer _exit(_enter())
    foo(1)
}
{% endhighlight go %}

Sweet! Hope that was informative.

In [`Part II`]({% post_url 2015-01-29-golang_trace_fns_part_2 %}), we will investigate moving this code to a library and extending it with some simple options.

