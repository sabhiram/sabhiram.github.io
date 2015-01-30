---
title: "Go Function Tracing, Part II"
categories: Go
tags: Go
enableChat: true
---

This is **Part II** of a two-part post on Function Tracing in `Go`.

In [`Part I`]({% post_url 2015-01-21-golang_trace_fns_part_1 %}), we investigated building functions to allow us to log a function's enter and exit. In this post, we will explore formalizing this code a little so we can wrap it in a neat library. We will also explore extending the tracer with a few options.

If you are too bored to read this, and just want to see the implementation for where this leads to, take a look at [`sabhiram/go-tracey`](https://github.com/sabhiram/go-tracey) on github.

### Library? Isn't that for books or something?

If you are not familiar with libraries in `Go`, take a gander [here](https://golang.org/doc/code.html#Library). It does a very good job of walking you through building a simple library with `Go`.

Jumping right into code, lets move our `enter()` and `exit()` functions into a separate file (in its own folder, lets call it "tracey").

We will create a library by declaring a `package tracey` and moving the previous enter and exit functions here:

*tracey/tracey.go*
{% highlight go %}
package tracey

import (
    "fmt"
    "runtime"
    "regexp"
)

func Enter() string {
    // Skip this function, and fetch the PC and file for its parent
    pc, _, _, _ := runtime.Caller(1)
    // Retrieve a Function object this functions parent
    functionObject := runtime.FuncForPC(pc)
    // Regex to extract just the function name (and not the module path)
    extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
    fnName := extractFnName.ReplaceAllString(functionObject.Name(), "$1")
    fmt.Printf("Entering %s\n", fnName)
    return fnName
}

func Exit(s string) {
    fmt.Printf("Exiting  %s\n", s)
}
{% endhighlight %}

Now we can add a file to use the above package (pay attention to the path, I just add this to the parent dir for convenience).
*foo.go*
{% highlight go %}
package main

import "github.com/sabhiram/tracey"

func main() {
    defer tracey.Exit(tracey.Enter())
}
{% endhighlight %}

This will now produce the following when run with `go run foo.go`:
{% highlight go %}
Entering main
Exiting  main
{% endhighlight %}

So far so good. Clearly writing out `defer tracey.Exit(tracey.Enter())` is a bit of a pain, so next we will look at how to make this a bit nicer.

### Look at all these exports!

So `Go` has some weird rules about what it exports (from structs, packages and what not). For more details check out [this](https://golang.org/doc/effective_go.html#package-names) link.

To clean up our code, we can expose a single function `New()` which returns the `Enter()` and `Exit()` functions to the caller. This simplifies our code to the following:

*tracey/tracey.go*
{% highlight go %}
package tracey

import (
    "fmt"
    "runtime"
    "regexp"
)

// Single entry-point to fetch trace functions
func New() (func(string), func() string) {

    // Define our enter function
    _enter := func() string {
        // Skip this function, and fetch the PC and file for its parent
        pc, _, _, _ := runtime.Caller(1)
        // Retrieve a Function object this functions parent
        functionObject := runtime.FuncForPC(pc)
        // Regex to extract just the function name (and not the module path)
        extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
        fnName := extractFnName.ReplaceAllString(functionObject.Name(), "$1")
        fmt.Printf("Entering %s\n", fnName)
        return fnName
    }

    // Define the exit function
    _exit := func(s string) {
        fmt.Printf("Exiting  %s\n", s)
    }

    // Return the trace functions to the caller
    return _exit, _enter
}
{% endhighlight %}

This changes the usage in *foo.go* to something like this:
{% highlight go %}
package main

import "github.com/sabhiram/tracey"

var Exit, Enter = tracey.New()

func main() {
    defer Exit(Enter())
}
{% endhighlight %}

Running `go run foo.go` will produce the same output as before (really, I promise).

### Options, options, options

Lets add some configuration options to the mix. Here is a [`struct`](http://www.golang-book.com/9/index.htm) which we will define some config parameters:
{% highlight go %}
type Options struct {
    // Setting "DisableNesting" to "true" will cause tracey to not indent
    // any messages from nested functions. The default value is "false"
    // which enables nesting by prepending "SpacesPerIndent" number of
    // spaces per level nested.
    DisableNesting      bool
    SpacesPerIndent     int

    // Private member, used to keep track of how many levels of nesting
    // the current trace functions have navigated.
    currentDepth        int
}
{% endhighlight %}

We will also need to modify `New` to accept a pointer to one such structure (or nil):
{% highlight go %}
func New(opts *Options) (func(string), func() string) {
    ...
    return _exit, _enter
}
{% endhighlight %}

Since `opts` is a pointer, lets do some error handling up-front:
{% highlight go %}
func New(opts *Options) (func(string), func() string) {
    var options Options
    if opts != nil {
        options = *opts
    }

    // If nesting is enabled, and the spaces are not specified,
    // use the "default" value of 2
    if options.DisableNesting {
        options.SpacesPerIndent = 0
    } else if options.SpacesPerIndent == 0 {
        options.SpacesPerIndent = 2
    }
    ...
}
{% endhighlight %}

In the above code, we instantiate a local copy of the `Options` (which is default initialized), and then assign it to the value pointed to by `opts` (as long as it's not nil). We then deal with setting the default value for the indent spacing. Note that since `options` is in the scope that contains the `_enter()` and `_exit()` functions - they will have access to it's members.

### Honor thy options!

Next up, we modify the `_enter()` and `_exit()` function to reflect the nesting of function calls. Also pay heed to `options.currentDepth` - we will use this to keep track of how many nested functions have been called.

We will also add the following helper functions within the scope of `New`:
1. `_spacify()` to return a string with the current depth worth of spaces
2. `_incrementDepth()` and `_decrementDepth()` to update `currentDepth`

Putting this all together we get the following for *tracey/tracey.go*:
{% highlight go %}
package tracey

import (
    "fmt"
    "strings"
    "runtime"
    "regexp"
)

type Options struct {
    // Setting "DisableNesting" to "true" will cause tracey to not indent
    // any messages from nested functions. The default value is "false"
    // which enables nesting by prepending "SpacesPerIndent" number of
    // spaces per level nested.
    DisableNesting      bool
    SpacesPerIndent     int    

    // Private member, used to keep track of how many levels of nesting
    // the current trace functions have navigated.
    currentDepth        int
}

// Single entry-point to fetch trace functions
func New(opts *Options) (func(string), func() string) {

    var options Options
    if opts != nil {
        options = *opts
    }

    // If nesting is enabled, and the spaces are not specified,
    // use the "default" value of 2
    if options.DisableNesting {
        options.SpacesPerIndent = 0
    } else if options.SpacesPerIndent == 0 {
        options.SpacesPerIndent = 2
    }

    _incrementDepth := func() {
        options.currentDepth += 1
    }

    _decrementDepth := func() {
        options.currentDepth -= 1
        if options.currentDepth < 0 {
            panic("Depth is negative! Should never happen!")
        }
    }

    _spacify := func() string {
        return strings.Repeat(" ", options.currentDepth * options.SpacesPerIndent)
    }

    // Define our enter function
    _enter := func() string {
        defer _incrementDepth()
        // Skip this function, and fetch the PC and file for its parent
        pc, _, _, _ := runtime.Caller(1)
        // Retrieve a Function object this functions parent
        functionObject := runtime.FuncForPC(pc)
        // Regex to extract just the function name (and not the module path)
        extractFnName := regexp.MustCompile(`^.*\.(.*)$`)
        fnName := extractFnName.ReplaceAllString(functionObject.Name(), "$1")
        fmt.Printf("%sEntering %s\n", _spacify(), fnName)
        return fnName
    }

    // Define the exit function
    _exit := func(s string) {
        _decrementDepth()
        fmt.Printf("%sExiting  %s\n", _spacify(), s)
    }

    // Return the trace functions to the caller
    return _exit, _enter
}
{% endhighlight %}

Since we changed the signature to the `New()` function, lets update *foo.go* (and make it a little more compelling while we are at it):
{% highlight go %}
package main

import "github.com/sabhiram/tracey"

var Exit, Enter = tracey.New(nil)

func nested() {
    defer Exit(Enter())
}

func main() {
    defer Exit(Enter())
    nested()
}
{% endhighlight %}

This will produce (with `go run foo.go`):
{% highlight go %}
Entering main
  Entering nested
  Exiting  nested
Exiting  main
{% endhighlight %}

If we wanted to change the options passed into `tracey.New`, all we would need to do is:
{% highlight go %}
var Exit, Enter = tracey.New(&tracey.Options{ SpacesPerIndent: 4 })
{% endhighlight %}

Which results in:
{% highlight go %}
Entering main
    Entering nested
    Exiting  nested
Exiting  main
{% endhighlight %}

### Where to go from here?

Here are some issues with the implementation so far:

1. Functions inside anonymous functions get assigned "func.ID" as their name where "ID" is n for the n-th anonymous function in a file. So perhaps the `_enter()` should accept an optional string to print.
2. It is not currently possible to pass `_enter()` a list of interfaces like we can with `fmt.Printf()`
3. We cannot (yet) customize the enter and exit messages
4. We cannot (yet) customize if the tracing is enabled or disabled
5. We cannot (yet) use a custom logger dump the trace messages to

### Wrapping up

Whew, that was a fun journey. If you found this interesting and want to dig deeper, or use `tracey` like functionality in your `go` project, take a look at [`sabhiram/go-tracey`](https://github.com/sabhiram/go-tracey). 

The `go-tracey` library implements the above missing pieces and then some. There are comprehensive examples and unit-tests to validate all parts of the library's functionality. Feedback welcome!
