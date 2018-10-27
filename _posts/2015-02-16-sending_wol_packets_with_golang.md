---
title: "Wake-on-LAN with Go"
categories: development
tags: Go, Wake-on-LAN, WOL
enableChat: false
---

Doing stuff remotely is pretty awesome. Nothing is cooler than banging a bunch of keys on a terminal, to result in the machine 3 feet away roar to life. Yes, it is within my reach, but hey where is the fun in that?!?

The process by which one might remotely power-on a machine (on the same LAN) is referred to as [`Wake-on-LAN (WOL)`](http://en.wikipedia.org/wiki/Wake-on-LAN). This process involves sending a specific payload over the local area network that a target machine is connected to. This payload is encoded with the MAC Address of the target machine.

It is also possible to wake machines not directly in your LAN, but this topic is out of the scope of this post. There are many security implications of allowing machines to be woken up via a network broadcast, therefore most machines will expose a setting in their BIOS to enable or disable remote power on.

### How does it work?

Assuming that the `Wake-on-LAN` settings have been enabled in a machine's BIOS, and said machine has a MAC address of `00:11:22:33:44:55`, we can power this machine on by sending a [`Magic Packet`](http://en.wikipedia.org/w/index.php?title=Wake-on-LAN&redirect=no#Magic_packet) encoded with its MAC address.

These packets are not protocol specific, and therefore can be sent using just about any network protocol. However, these are typically sent as a [`UDP Packet`](http://en.wikipedia.org/wiki/User_Datagram_Protocol).

### Show me the Magic!

A Magic Packet is defined as any payload that contains the following pattern:

1. 6 bytes of `0xFF`
2. 16 repetitions of the target's 48-bit MAC address (16 * 6 bytes)

Note that the relevant part of the Magic Packet is 6 + (16 * 6) = 102 bytes. The payload however can be larger, as long as the above pattern can be found.

Time to get coding. Lets define our packet:
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

Since the only real "input" to a MagicPacket is a valid MAC address, it should make sense to have a convenience function to create, initialize and inject the MAC address into a new MagicPacket.

First some globals. Here we call out the delims which might separate the bytes of a MAC Address, and a Regex to match for valid MAC Addresses:
{% highlight go %}
// Define globals for MacAddress parsing
var (
    delims = ":-"
    re_MAC = regexp.MustCompile(`^([0-9a-fA-F]{2}[`+delims+`]){5}([0-9a-fA-F]{2})$`)
)
{% endhighlight %}

To convert a MAC Address string into a [`net.HardwareAddr`](http://golang.org/pkg/net/#HardwareAddr), we can use [`net.ParseMAC()`](http://golang.org/pkg/net/#ParseMAC).  Once we have our set of bytes, all we need to do is fill our MagicPacket.

{% highlight go %}
// This function accepts a MAC Address string, and returns a pointer to
// a MagicPacket object. A Magic Packet is a broadcast frame which
// contains 6 bytes of 0xFF followed by 16 repetitions of a given mac address.
func NewMagicPacket(mac string) (*MagicPacket, error) {
    var packet MagicPacket
    var macAddr MACAddress

    // We only support 6 byte MAC addresses
    if !re_MAC.MatchString(mac) {
        return nil, errors.New("MAC address " + mac + " is not valid.")
    }

    hwAddr, err := net.ParseMAC(mac)
    if err != nil {
        return nil, err
    }

    // Copy bytes from the returned HardwareAddr -> a fixed size MACAddress
    for idx := range macAddr {
        macAddr[idx] = hwAddr[idx]
    }

    // Setup the header which is 6 repetitions of 0xFF
    for idx := range packet.header {
        packet.header[idx] = 0xFF
    }

    // Setup the payload which is 16 repetitions of the MAC addr
    for idx := range packet.payload {
        packet.payload[idx] = macAddr
    }

    return &packet, nil
}
{% endhighlight %}

Awesome, now we can do something like this to get a MagicPacket from a MAC Address:
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

We now have a nicely formed MagicPacket, all we need to do is send this data out as a UDP broadcast. This basically involves converting the MagicPacket into a []byte which we can then feed into a UDP connection that we will form.

{% highlight go %}
// This function accepts a MAC address string, and s
// Function to send a magic packet to a given mac address
func SendMagicPacket(macAddr string) error {
    magicPacket, err := NewMagicPacket(macAddr)
    if err != nil {
        return err
    }

    // Fill our byte buffer with the bytes in our MagicPacket
    var buf bytes.Buffer
    binary.Write(&buf, binary.BigEndian, magicPacket)

    // Get a UDPAddr to send the broadcast to
    udpAddr, err := net.ResolveUDPAddr("udp", "255.255.255.255:9")
    if err != nil {
        fmt.Printf("Unable to get a UDP address for %s\n", "255.255.255.255:9")
        return err
    }

    // Open a UDP connection, and defer its cleanup
    connection, err := net.DialUDP("udp", nil, udpAddr)
    if err != nil {
        fmt.Printf("Unable to dial UDP address for %s\n", "255.255.255.255:9")
        return err
    }
    defer connection.Close()

    // Write the bytes of the MagicPacket to the connection
    bytesWritten, err := connection.Write(buf.Bytes())
    if err != nil {
        fmt.Printf("Unable to write packet to connection\n")
        return err
    } else if bytesWritten != 102 {
        fmt.Printf("Warning: %d bytes written, %d expected!\n", bytesWritten, 102)
    }

    return nil
}
{% endhighlight %}

### Wrapping up

We looked at defining a bunch of bytes to form a MagicPacket, then we went about initializing the packet based on a given input MAC address. Then we explored using the [`net package`](http://golang.org/pkg/net/) to send a bunch of bytes as a UDP broadcast to wake our target machine.

I hope this was somewhat useful. If this was interesting, and you want to check out a more complete, command line version of this utility - take a look at: [`sabhiram/go-wol`](https://github.com/sabhiram/go-wol).
