---
title: "Wake-on-LAN with Go"
categories: development
tags: Go, Wake-on-LAN, WOL
enableChat: true
---

Doing stuff remotely is pretty awesome. Nothing is cooler than banging a bunch of keys on a terminal, to result in the machine 3 feet away roar to life. Yes, it is within my reach, but hey where is the fun in that?!?

The process by which one might remotely power-on a machine (on the same LAN) is referred to as [`Wake-on-LAN (WOL)`](http://en.wikipedia.org/wiki/Wake-on-LAN). This process involves sending a specific payload on the local area network. Said payload is encoded with a target machine's MAC address. If the target machine's Ethernet interface receives this broadcast - it powers on the target machine!

It is also possible to wake machines not directly in your LAN, but this topic is out of the scope of this post. There are many security implications of allowing machines to be woken up via a network broadcast, therefore most machines will expose a setting in their BIOS to enable or disable remote power on. 

### How does it work?

Assuming that the `Wake-on-LAN` settings have been enabled in a machine's BIOS, and said machine has a MAC address of `00:11:22:33:44:55`, we can power this machine on by sending a [`Magic Packet`](http://en.wikipedia.org/w/index.php?title=Wake-on-LAN&redirect=no#Magic_packet) encoded with it's MAC address.

These `Magic Packets` are not protocol specific, and therefore can be sent using just about any network protocol. However, these are typically sent as a [`UDP Packet`](http://en.wikipedia.org/wiki/User_Datagram_Protocol).

### Show me the Magic!

A `Magic Packet` is defined as any payload that contains the following pattern:

1. 6 bytes of `0xFF`
2. 16 repetitions of the targets 48-bit MAC address (16 * 6 bytes)

Note that the relevant part of the `Magic Packet` is 6 + (16 * 6) = 102 bytes. The payload however can be larger, as long as the above pattern can be found.

Ok, time to get coding. Lets define what we need to form a `MagicPacket`:
{% highlight go %}
// A MacAddress is 6 bytes in a row
type MacAddress [6]byte

// A MagicPacket is constituted of 6 bytes of 0xFF followed by
// 16 groups of the destination MAC address.
type MagicPacket struct {
    header  [6]byte
    payload [16]MacAddress
}
{% endhighlight %}

### Initializing a Magic Packet

Since the only real "input" to a `MagicPacket` is a valid MAC address, it should make sense to have a convenience function to create, initialize and inject the MAC address into a new `MagicPacket`.

First some globals. Here we call out the delims which might separate the bytes of a MAC Address, and a Regex to match for valid MAC Addresses:
{% highlight go %}
// Define globals for MacAddress parsing
var (
    delims = ":-"
    re_MAC = regexp.MustCompile(`^([0-9a-fA-F]{2}[` + delims + `]){5}([0-9a-fA-F]{2})$`)
)
{% endhighlight %}

Next, lets write a small helper function which takes a valid MAC Address string, and returns a pointer to a `MacAddress`:
{% highlight go %}
func GetMacAddressFromString(mac string) (*MacAddress, error) {
    // First strip the delimiters from the valid MAC Address
    for _, delim := range delims {
        mac = strings.Replace(mac, string(delim), "", -1)
    }

    // Fetch the bytes from the string representation of the
    // MAC address. address is []byte
    address, err := hex.DecodeString(mac)
    if err != nil {
        return nil, err
    }

    var ret MacAddress
    for idx, _ := range ret {
        ret[idx] = address[idx]
    }
    return &ret, nil
}
{% endhighlight %}

Finally, we write a function which accepts a MAC Address (as a string), and returns a pointer to a `MagicPacket`:
{% highlight go %}
func NewMagicPacket(mac string) (*MagicPacket, error) {
    var packet MagicPacket

    // Parse the MAC Address into a "MacAddress". For the time being, only
    // the traditional methods of writing MAC Addresses are supported.
    // XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX will match. All others will throw
    // up an error to the caller.
    if re_MAC.MatchString(mac) {
        // Setup the header which is 6 repetitions of 0xFF
        for idx, _ := range packet.header {
            packet.header[idx] = 0xFF
        }

        addr, err := GetMacAddressFromString(mac)
        if err != nil {
            return nil, err
        }

        // Setup the payload which is 16 repetitions of the MAC addr
        for idx, _ := range packet.payload {
            packet.payload[idx] = *addr
        }

        return &packet, nil
    }
    return nil, errors.New("Invalid MAC address format seen with " + mac)
}
{% endhighlight %}

Awesome, now we can do something like this to get a `MagicPacket` from a MAC Address:
{% highlight go %}
magicPacket, err := NewMagicPacket("00:11:22:33:44:55")
if err == nil {
    fmt.Printf("Magic Packet: %v\n", magicPacket)
}
{% endhighlight %}

This produces:
{% highlight go %}
Magic Packet: &{[255 255 255 255 255 255] [[0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85] [0 17 34 51 68 85]]}
{% endhighlight %}

### Put that in a pipe!

So we have a nicely formed `MagicPacket`, now to get this data sent as a UDP broadcast. First, convert the `magicPacket` we formed above into a bunch of bytes:
{% highlight go %}
import (
    "encoding/binary"
    "bytes"
    "net"
)

var buf bytes.Buffer
binary.Write(&buf, binary.BigEndian, magicPacket)
{% endhighlight %}

Fetch a `UDPAddr*` from the broadcast address / port we wish to send the packet to (in this case 255.255.255.255:9):
{% highlight go %}
udpAddr, err := net.ResolveUDPAddr("udp", "255.255.255.255:9")
if err != nil {
    fmt.Printf("Unable to get a UDP address for 255.255.255.255:9\n")
    return err
}
{% endhighlight %}

Connect to the address (and also setup the closing of the connection once this function exits):
{% highlight go %}
connection, err := net.DialUDP("udp", nil, udpAddr)
if err != nil {
    fmt.Printf("Unable to dial UDP address for 255.255.255.255:9\n")
    return err
}
defer connection.Close()
{% endhighlight %}

Finally, we write the bytes stored in `buf` to the above connection:
{% highlight go %}
bytesWritten, err := connection.Write(buf.Bytes())
if err != nil {
    fmt.Printf("Unable to write magic packet to connection\n")
    return err
}
{% endhighlight %}

### Wrapping up

We looked at defining a bunch of bytes to form a `MagicPacket`, then we went about initializing the packet based on a given input MAC address. We also explored using the [`net package`](http://golang.org/pkg/net/) to send a bunch of bytes as a UDP broadcast to wake our target machine.

I hope this was somewhat useful. If this was interesting, and you want to check out a more complete, command line version of this utility - take a look at: [`sabhiram/go-wol`](https://github.com/sabhiram/go-wol).
