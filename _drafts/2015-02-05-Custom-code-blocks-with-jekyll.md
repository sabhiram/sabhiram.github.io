---
title: "Plugin-less Custom Highlighting with Jekyll"
categories: Jekyll
tags: Jekyll, Blog, CSS
openQuote: "<div class='blog-quote'>"
closeQuote: "</div>"
---

I am rather new to building static content using Jekyll, and am blown away by how simple the whole process from writing text, to having it show up on my github.io page has become. Along my path, I wanted a simple way to enable plugin-less (keep reading to find out why) custom highlighting in my blog.

Something like this:

{{ page.openQuote }}
The quick <b>brown</b> fox jumps over the lazy dog
{{ page.closeQuote }}

Or this:

{{ page.openQuote }}
Why, man, he doth bestride the narrow world<br>
Like a Colossus, and we petty men<br>
Walk under his huge legs and peep about<br>
To find ourselves dishonourable graves.<br>
{{ page.closeQuote }}

The following post curates my exploits in seeking out the above functionality, without boiling the ocean.

### Code Highlighting in Jekyll

["Code" Highlighting](http://jekyllrb.com/docs/posts/#highlighting-code-snippets) with Jekyll is pretty awesome and is as simple as wrapping your text with the respective `highlight` liquid tags as shown below:

{% raw %}
```
{% highlight python %}
# This is a comment
odyssey = space % 2001
{% endhighlight %}
```
{% endraw %}

Which produces the following output:
{% highlight python %}
# This is a comment
odyssey = space % 2001
{% endhighlight %}

Looking at the generated HTML, we see something like:
{% highlight html %}
<div class="highlight">
  <pre>
    <code class="language-python" data-lang="python">
      <span class="c"># This is a comment</span>
      <span class="n">odyssey</span> <span class="o">=</span> <span class="n">space</span> <span class="o">%</span> <span class="mi">2001</span>
    </code>
  </pre>
</div>
{% endhighlight html %}

Basically, Jekyll scans the code / text within the {% raw %}`{% highlight %}`{% endraw %} tag, and post processes it. Neat, so to add custom styling for quotes - we should just be able to define a custom language and style it as we see fit (we can style the container as well as the content). 

However, Jekyll only works with a preset [list of languages](http://pygments.org/languages/) as supported by [`pygments`](http://pygments.org/) or [`rouge`](https://github.com/jneen/rouge). Certainly one option here, is to pick a language you never plan on highlighting with, and just use that anytime you wanted a quote. This sounds icky. Perhaps we can do our quote styling with a plugin instead.

### Plugins in Jekyll

From scratching the surface, it was clear that Jekyll could be easily extended by means of simple [plugins](http://jekyllrb.com/docs/plugins/). However, the large note on said page also cautions the reader that the `github pages` version of the generated site, will use the `--safe` option when baking the static site. This means custom plugins are excluded when the static site is built! Clearly, we could just set-up Jekyll locally on our dev boxes and push the generated site to github, but where is the fun in that?

### Ok so no plugins, now what?

One other option, would be to write raw HTML in your markdown document. We could just do something like this:

{% highlight html %}
<div class="blog-quote">
The quick <b>brown</b> fox jumps over the lazy dog
</div>
{% endhighlight %}

and style the `blog-quote` class like so (excuse my sass):
{% highlight scss %}
.blog-quote {
    position:     relative;
    margin:       15px 10px;
    padding-left: 12px;
    overflow-x:   auto;

    font-size:    1rem;
    font-style:   italic;
    color:        #9B9B9B;
    line-height:  1.25;

    border-color: #039BE5;
    border-left:  10px solid #039BE5;

    // Fix <b> tag inside a quote
    & b {
        color:    #424242;
    }
}
{% endhighlight %}

This totally works, but is rather ugly. Putting a bunch of divs in the blog text seems like a step backwards. 

### The Unlikely Savior(?) - Front Matter

Each Jekyll page can contain a header section which defines a bunch of [`Front Matter`](http://jekyllrb.com/docs/frontmatter/). This is used to choose page specific layouts, set page attributes and what not in the Jekyll world. Here is an overview on [`Liquid Variables`](https://github.com/Shopify/liquid/wiki/Liquid-for-Designers#variable-assignment).

For instance, if we had the following `Front Matter` on the top of our current post like so:
{% highlight html %}
---
layout: "post"
title: "Post about stuff"
openQuote: "<div class='blog-quote'>"
closeQuote: "</div>"
---
# Some stuff!
{% endhighlight %}

Then, anytime we wanted a "quote", we can "emit" the `openQuote` and `closeQuote` values using the {% raw %}`{{ var_name }}`{% endraw %} liquid syntax.

So if we wanted to inject a quote into a post, it would now look something like this:
{% highlight html %}
{% raw %}
{{ page.openQuote }}
The quick <b>brown</b> fox jumps over the lazy dog
{{ page.closeQuote }}
{% endraw %}
{% endhighlight %}

This will produce the desired effect (using the same css from above), which is seen here:

{{ page.openQuote }}
The quick <b>brown</b> fox jumps over the lazy dog
{{ page.closeQuote }}

### Making things a little easier

Let's say we end up quoting things a whole bunch. We would have to add the `openQuote` and `closeQuote` variables to each and every post's `Front Matter`. This is not very sane, but fortunately Jekyll allows us to specify page wide [`defaults`](http://jekyllrb.com/docs/configuration/#front-matter-defaults).

This would allow us to define the blocks of HTML we wish to inject, up-front in the config file. For example, to apply the `openQuote` and `closeQuote` variables to all "posts", your `_config.yml` file would resemble:
{% highlight yaml %}
... other settings
defaults:
  -
    scope:
        path: ""
        type: "posts"
    values:
        openQuote: "<div class='blog-quote'>"
        closeQuote: "</div>"
{% endhighlight %}

Woot! From now on, any "posts" related page will auto-magically have access to the `openQuote` and `closeQuote` variables. The usage still remains the same, use {% raw %}`{{ page.openQuote }}` and `{{ page.closeQuote }}`{% endraw %} to inject them.

### And next time...

What if we wanted to control the color of the quote bar?

{% include plugins/quote.html start=true color="red" %}
The quick <b>brown</b> fox jumps over the lazy dog
{% include plugins/quote.html %}

Or add an author (optionally?)

{% include plugins/quote.html start=true color="purple" author="A Pangram" %}
The quick <b>brown</b> fox jumps over the lazy dog
{% include plugins/quote.html %}

In the next post, I will explore a slightly different approach at building very simple "plugins" within our Jekyll / Liquid eco-system.

