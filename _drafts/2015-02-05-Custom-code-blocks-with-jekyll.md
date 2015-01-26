---
title: "Plugin-less Custom Highlighting with Jekyll"
categories: Jekyll
tags: Jekyll, Blog, CSS
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

## Code Highlighting in Jekyll

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

However, Jekyll only works with a preset [list of languages](http://pygments.org/languages/) as supported by [`pygments`](http://pygments.org/). Certainly one option here, is to pick a language you never plan on highlighting with, and just use that anytime you wanted a quote. This sounds icky. Perhaps we can do our quote styling with a plugin instead.

## Plugins in Jekyll

From scratching the surface, it was clear that Jekyll could be easily extended by means of simple [plugins](http://jekyllrb.com/docs/plugins/). However, the large note on said page also cautions the reader that the `github pages` version of the generated site, will use the `--safe` option when baking the static site. This means custom plugins are excluded when the static site is built! Clearly, we could just set-up Jekyll locally on our dev boxes and push the generated site to github, but where is the fun in that?

## The Unlikely Savior - Front Matter
