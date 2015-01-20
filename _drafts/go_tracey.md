---
layout: post
title: "Go Function Tracing - aka: fun with defer"
categories: Go
tags: Go
---

Google's `Go` is pretty cool, and fairly fast. A few weeks ago, I finally got around to messing with it. I wrote a couple of simple library functions and decided that I wanted to build a function tracing library.

The following is an attempt to document my previously stated journey. Be warned, I have only been `Go`ing for the better part of the week.

### Some code

Ok, so lets say we have the following code in file *foo.go*:
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

Running the code above with `go run foo.go` would produce something eerily similar to this:
{% highlight sh %}
$ go run foo.go
Entering main
Entering foo(2)
Entering bar(1)
Entering foo(1)
Entering bar(0)
Entering foo(0)
{% endhighlight %}

### <u>Goal 1:</u> Track Function Enter / Exit (... easily)

Ok so clearly, the naive approach here would be to just tag the `Enter` of a function on function entry (as we did), and then tag the `Exit` before any branches which invoke a return. Even thinking about that makes me feel icky.

Thankfully `Go` provides us with this nifty [`defer` statement](https://golang.org/ref/spec#Defer_statements), which we just might have to abuse a little.

From the documentation for `defer`:
*"Each time a "defer" statement executes, the function value and parameters to the call are evaluated as usual and saved anew but the actual function is not invoked. Instead, deferred functions are invoked immediately before the surrounding function returns, in the reverse order they were deferred"*

Ahh, so if we `defer` something immediately after we enter a function, then `Go` will invoke said deferred statement once the function we are executing returns. This is really cool! Without this, we would have to cover every returning branch of code with the exit message. Ok, so lets take another stab at our code, enriched with the power of `defer`:

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

Now `go run foo.go` produces:
{% highlight sh %}
$ go run foo.go
Entering main()
Entering foo(2)
Entering bar(1)
Entering foo(1)
Entering bar(0)
Entering foo(0)
Exiting foo(0)
Exiting bar(0)
Exiting foo(1)
Exiting bar(1)
Exiting foo(2)
Exiting main()
{% endhighlight sh %}

Great! We avoided having to print an exit statement for each branch which returned from the function. So now logic dictates that typing two ugly `fmt.Printf(..)` statements in each and every function is kind of overkill (and rather gross). 

### <u>Goal 2:</u> Avoid having to specify the function name



### <u>Goal 3:</u> One* for the price of Two

### <u>Goal 4:</u> Pulling it all into a Library

### <u>Goal 5:</u> Extending the code, default options and more
