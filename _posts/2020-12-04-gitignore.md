---
title: "CLI hacks - edit closest .gitignore file"
categories: Shell Git
tags: git, shell, development
---

Picture this: You are a `.git` knight, knee deep in a valley of edits, half-way around a rebase, all is going well as you catch a glimpse of it. There it is, just sitting there mocking you, acting like it belongs. Perhaps an artifact of generation, perhaps a symbol, perhaps a whole other valley of edits. You know one thing: this vileness cannot be included in our pristine tree! Not near anything that is main or master! The problem is, you are not sure where in your path, you last met the formidable `.gitignore` file.

If this is you, I have good news!

<img src="https://raw.githubusercontent.com/sabhiram/public-images/master/sabhiram.github.io/good-news.png" width="100%" alt="Good News!" />
<br /><br />

Add this nifty shell function to your shell (`~/.bash_*whatever*`) and you will be off to the jousts in no time!

{% highlight shell %}
gitignore () {
  # Verify we are inside a `.git` tree
  git rev-parse

  # Iterate up to either `.git` or a valid `.gitignore` path.
  path=$(pwd)
  pattern=$1
  while [ "$path" != "" ] && [ ! -e "$path/.gitignore" ] && [ ! -d "$path/.git" ]; do
    pattern=${path##*/}/$pattern
    path=${path%/*}
  done

  # We either found a `.git` directory with no `.gitignore` file, or found
  # another valid `.gitignore` up the parent directories. Append to it!
  echo $pattern >> $path/.gitignore
  echo $path/.gitignore
}
{% endhighlight %}

Usage:
{% highlight shell %}
$ gitignore *.o
$ cat .gitignore 
*.o
$ mkdir a && cd a
$ gitignore foo*.cpp
$ cat ../.gitignore 
*.o
a/foo*.cpp
{% endhighlight %}
