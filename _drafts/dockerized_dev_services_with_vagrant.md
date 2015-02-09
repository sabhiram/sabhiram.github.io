---
title: "Dockerized Dev Services with Vagrant"
categories: development
tags: Docker, Vagrant, Grunt, NodeJS
enableChat: false
---

![Happy Developers](https://raw.githubusercontent.com/sabhiram/public-images/master/sabhiram.github.io/docker_vagrant.png)

Lets say you are building a nifty little service, and all of a sudden you want a MongoDB instance to do some testing. Our typical work-flow will have us throw up a Mongo instance on whatever dev box we are developing on, and carefully co-ordinate when and how things are launched. 

One, perhaps slightly saner approach, would be to `Dockerize` the service and run an image of the MongoDB service on your dev box. This is pretty cool because it allows us to isolate this instance of Mongo, which is much better than hammering your production DB server for some testing / bring up.

The only problem with `Docker` is that we need to ensure that the host machine is correctly configured and running the Docker daemon. This can also affect portability as Docker does not support a Windows client (yet). 

Enter `Vagrant`, which allows us to define, provision and manage VMs which can in-turn consistently host our `Docker` image(s).

In this post, I will explore one such method of organization within a simple NodeJS project. This can obviously extend to just about any environment just as long as you have `Vagrant` installed on your dev box(es). I have just choosen NodeJS as my medium of expression since there are a lot of support modules to make my life easier (Grunt, et al), but the general principle will hold true for just about any language which can invoke a shell command.

### What are we trying to build?

```
+---------- Dev Box -----------\
|                              | 
|  +-------- Vagrant VM -----\ |
|  |                         | |
|  |  +-- Docker Service --\ | |
|  |  |  MongoDB - 0       | | |
|  |  \--------------------/ | |
|  |                         | |
|  |  +-- Docker Service --\ | |
|  |  | Some other service | | |
|  |  \--------------------/ | |
\------------------------------/
```

The above image shows the intended nesting of our service within our dev box. First there is the dev itself. The dev box then runs a `Vagrant` VM which is capable of hosting the `Docker` daemon. Within said `Vagrant` VM, we spin up various images related to the given service.

We will discuss how to manage the spinning up of said services a bit later. First let us get some pre-requisites out of the way.

### Requirements

A dev box (I am using a Mac Book Pro running OSX 10.9 for reference).

Vagrant installed on said Dev box. Please check out [this page](https://www.vagrantup.com/downloads.html) for an up-to-date binary installer for your OS of choice.

The next few things are just so we can test our service and make sure things are working as expected. For this, we will be using `NodeJS` + `Grunt`.

To install `Grunt`, just run `npm install grunt-cli -g`.

### Sample Project Layout

Lets assume that we want to build a small NodeJS app which interfaces with an instance of MongoDB which we are trying to Dockerize within a Vagrant VM. Our folder structure would look something like this:

```
+ Parent Dir
|-- package.json
|-- Gruntfile.js
|-- server.js
|-+ services
  |-+ mongodb
    |-- Vagrantfile
    |-- Dockerfile
    |-- init.sh
```

In our parent folder we have:

| File | Usage |
| ---- | ----- |
| package.json | This just tells npm how to install / configure our application |
| Gruntfile.js | This file tells Grunt what jobs to process and automate |
| server.js | This is our simple App to talk to the MongoDB instance |
| services | This is a folder containing various services we wish to spin up |
|---- | ----- |

And within the `services\mongodb` folder we have:

| File | Usage |
| ---- | ----- |
| Vagrantfile | This tells vagrant what type of VM to spin up and how to provision it |
| Dockerfile | This describes to the Docker client, how to image and run this service |
| init.sh | A provisioning script, which will build our docker image, and run it on our fresh new VM |
|---- | ----- |

The code for the above mock project can be found here: [`node-mongo-service-demo`](https://github.com/sabhiram/node-mongo-service-demo).

