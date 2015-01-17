---
layout: post
title: "Go Function Tracing - aka: fun with defer"
categories: Go
tags: Go
---

Google's `Go` is pretty cool, and fairly fast. A few weeks ago, I finally got to messing around with it. I wrote a couple of simple library functions and decided that I wanted to build a function tracing library.

The following is an attempt to document my previously stated journey. Be warned, I have only been `Go`ing for the better part of the week.

Ok, so lets say we have the following code:

*foo.go*
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
    foo(2)
}
{% endhighlight %}

Running the code above would produce something eerily similar to this:
{% highlight sh %}
$ go run foo.go
Entering main
Entering foo(2)
Entering bar(1)
Entering foo(1)
Entering bar(0)
Entering foo(0)
{% endhighlight %}

Ok so clearly, the naive approach here would be to just tag the `Enter` of a function on function entry (as we did), and then tag the `Exit` before any branches which invoke a return (and before the function is done being defined). That just feels icky.

Thankfully `Go` provides us with this nifty [`defer` statement](https://golang.org/ref/spec#Defer_statements), which we might just have to abuse a little. From the documentation for `defer`:

*"Each time a "defer" statement executes, the function value and parameters to the call are evaluated as usual and saved anew but the actual function is not invoked. Instead, deferred functions are invoked immediately before the surrounding function returns, in the reverse order they were deferred"*

Ahh, so if we `defer` something immediately after we enter a function, then `Go` will invoke said deferred function once the function we are executing returns. This is really cool! Without this, we would have to cover every returning branch of code with the exit message. Ok, so lets take another stab at our code, enriched with the power of `defer`:

*foo.go*
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
    foo(2)
}
{% endhighlight %}
