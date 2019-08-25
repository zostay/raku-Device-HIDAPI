class Device::HIDAPI::InternalDeviceInfo
----------------------------------------

hidapi info structure from C

class Device::HIDAPI::DeviceInfo
--------------------------------

The hidapi device info structure provided to Perl 6 callers

### sub hid_exit

```perl6
sub hid_exit() returns int32
```

Initialize the HIDAPI library.

### sub hid_enumerate

```perl6
sub hid_enumerate(
    uint16 $vendor-id,
    uint16 $product-id
) returns NativeCall::Types::Pointer[Device::HIDAPI::InternalDeviceInfo]
```

Enumerate the HID Devices

### sub hid_free_enumeration

```perl6
sub hid_free_enumeration(
    NativeCall::Types::Pointer[Device::HIDAPI::InternalDeviceInfo] $devs
) returns Mu
```

Free an enumeration Linked List

### sub hid_open

```perl6
sub hid_open(
    uint16 $vendor-id,
    uint16 $product-id,
    Str $serial-number
) returns Device::HIDAPI
```

Open a HID device using a Vendor ID (VID, Product ID (PID) and optionally a serial number.

### sub hid_open_path

```perl6
sub hid_open_path(
    Str $path
) returns Device::HIDAPI
```

Open a HID device by its path name.

### sub hid_write

```perl6
sub hid_write(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[uint8] $data,
    NativeCall::Types::size_t $length
) returns int32
```

Write an Output report to a HID device.

### sub hid_read_timeout

```perl6
sub hid_read_timeout(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[uint8] $data,
    NativeCall::Types::size_t $length,
    uint32 $milliseconds
) returns int32
```

Read an Input report from a HID device with timeout.

### sub hid_read

```perl6
sub hid_read(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[uint8] $data,
    NativeCall::Types::size_t $length
) returns int32
```

Read an Input report from a HID device.

### sub hid_set_nonblocking

```perl6
sub hid_set_nonblocking(
    Device::HIDAPI $dev,
    int32 $nonblock
) returns int32
```

Set the device handle to be non-blocking.

### sub hid_send_feature_report

```perl6
sub hid_send_feature_report(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[uint8] $data,
    NativeCall::Types::size_t $length
) returns int32
```

Send a Feature report to the device.

### sub hid_get_feature_report

```perl6
sub hid_get_feature_report(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[uint8] $data,
    NativeCall::Types::size_t $length
) returns int32
```

Get a feature report from a HID device.

### sub hid_close

```perl6
sub hid_close(
    Device::HIDAPI $dev
) returns Mu
```

Close a HID device.

### sub hid_get_manufacturer_string

```perl6
sub hid_get_manufacturer_string(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[int32] $string,
    NativeCall::Types::size_t $maxlen
) returns int32
```

Get The Manufacturer String from a HID device.

### sub hid_get_product_string

```perl6
sub hid_get_product_string(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[int32] $string,
    NativeCall::Types::size_t $maxlen
) returns int32
```

Get The Product String from a HID device.

### sub hid_get_serial_number_string

```perl6
sub hid_get_serial_number_string(
    Device::HIDAPI $dev,
    NativeCall::Types::CArray[int32] $string,
    NativeCall::Types::size_t $maxlen
) returns int32
```

Get The Serial Number String from a HID device.

### sub hid_get_indexed_string

```perl6
sub hid_get_indexed_string(
    Device::HIDAPI $dev,
    int32 $string-index,
    NativeCall::Types::CArray[int32] $string,
    NativeCall::Types::size_t $maxlen
) returns int32
```

Get a string from a HID device, based on its string index.

### sub hid_error

```perl6
sub hid_error(
    Device::HIDAPI $dev
) returns Str
```

Get a string describing the last error which occurred.

NAME
====

Device::HIDAPI - low-level HID interface

SYNOPSIS
========

    use Device::HIDAPI;

    # Read the raw inputs from an XBox One controller
    sub MAIN(Str $path) {

        # $path is the device path
        my $hid = Device::HIDAPI.new($path);

        loop {
            my $data = $dev.read;

            # Read the positions of the left stick
            my $lsx = $data.read-int16(6);
            my $lsy = $data.read-int16(8);

            say "$lsx, $lsy";
        }
    }

DESCRIPTION
===========

If you need to perform low-level interfacing with a HID (device implementing the Human Interface Device protocol), this library is for you. It depends on a C library named hidapi, which you can get from the libusb project (see INSTALLATION for details).

This is a low-level library, so if you want to interface with a keyboard, mouse, joystick or other standard equipment, there's probably a better way. However, if you have a HID that implements a custom protocol or you need to get to the raw device data for some reason, this library will get you there. It provides a binary interface to read and write data to HIDs.

CLASSES
=======

Device::HIDAPI
--------------

This class is the primary interface for enumerating devices, All the methods defined under METHODS below belong to this class.

Device::HIDAPI::Config
----------------------

This is a special compile-time generated class that configures the library to use. You should never need to do anythign with this yourself.

Device::HIDAPI::DeviceInfo
--------------------------

Objects of this type are returned by the device enumeration method. It provides the following read-only attributes about each device:

Pod::Defn<140187063716320>

Pod::Defn<140187063716264>

Pod::Defn<140187063716208>

Pod::Defn<140187063716096>

Pod::Defn<140187071420720>

Pod::Defn<140187071420664>

Pod::Defn<140187071420608>

Pod::Defn<140187071420552>

Pod::Defn<140187071420496>

Pod::Defn<140187071420440>

X::Device::HIDAPI
-----------------

This is the exception object used whenever a wrapped `hidapi` function returns an error. It provides two attributes:

Pod::Defn<140187071420272>

Pod::Defn<140187071420216>

METHODS
=======

method enumerate
----------------

    method enumerate(Device::HIDAPI:_:
        UInt $vendor-id = 0,
        UInt $product-id = 0,
        --> Seq
    )

This method is used to enumerate the devices known to the system.

    # list all the VIDs and PIDs
    for Device::HIDAPI.enumerate -> $dev {
        say "$dev.vendor-id():$dev.product-id() "
          ~ "- $dev.manufacturer-string(): "
          ~ "$dev.product-string()";
    }

The `$vendor-id` and `$product-id` can be set to specific numbers to list only devices matching those IDs. A value of 0 (the default) matches all IDs (i.e., list all).

method new
----------

    multi method new(Device::HIDAPI:U:
        UInt :$vendor-id!,
        UInt :$product-id!,
        Str :$serial-number,
        --> Device::HIDAPI:D
    )

    multi method new(Device::HIDAPI:U:
        Str:D :$path!
        --> Device::HIDAPI:D
    )

These constructors return an instance of `Device::HIDAPI`, which can be used to read from and write to the device. You may construct the object either using the `$vendor-id` and the `$product-id` or the `$path` to the device. It is possible to have multiple of the same device connected, in which case you may also want to provide the `$serial-number` when using the VID and PID.

method write
------------

    method write(Device::HIDAPI:D: blob8 $data --> UInt:D)

Writes the given blob to the device. Returns the number of bytes actually written.

method read-timeout
-------------------

    method read-timeout(Device::HIDAPI:D: UInt:D $millis --> blob8:D)

Reads data from the device or fails with an exception. If the device does not return anything within `$millis` milliseconds it returns an empty `Blob`.

Throws an exception if there's an error during the read.

method read
-----------

    method read(Device::HIDAPI:D: --> blob8:D)

Reads data from the device. Unless the object has been set to use non-blocking operations, this operation will block until data becomes available. If non-blocking has been set, then this will return data if any is waiting or return an empty `Blob` immediately if none is currently ready to read.

Throws an exception if there's an error during the read.

method set-nonblocking
----------------------

    method set-nonblocking(Device::HIDAPI:D: Bool:D $nonblock)

Sets the device as non-blocking or not based on the value of `$nonblock`. If the object is set to non-blocking, then calls to [/method read](/method read) will not block.

May throw an exception if an error occurs making a change to the device object.

method send-feature-report
--------------------------

    method send-feature-report(Device::HIDAPI:D: blob8 $data --> UInt:D)

Sends a feature rreport to the device. Returns the number of bytes written.

Throws an exception if there is an error performing the write.

method get-feature-report
-------------------------

    method get-feature-report(Device::HIDAPI:D: --> blob8:D)

Retrieve a feature report from the device.

Throws an exception if there is an error performing the read.

method close
------------

    method close(Device::HIDAPI:D:)

Closes the device and frees up associated resources. You should call this manually after creating the object if you want to make sure resources are freed before the garbage collector gets around to freeing memory:

    # You can make calling this automatic when the variable goes out of scope
    # like this...
    my Device::HIDAPI:D $dev is leave({ .close }) .= new($path);

Throws an error if there is a problem releasing the object.

method get-manufacturer-string
------------------------------

    method get-manufacturer-string(Device::HIDAPI:D: --> Str:D)

Retrieves the manufacturer string from the device.

Throws an error if there's a problem getting the data from the device.

method get-product-string
-------------------------

    method get-product-string(Device::HIDAPI:D: --> Str:D)

Retrieves the product string from the device.

Throws an error if there's a problem getting the data from the device.

method get-serial-number-string
-------------------------------

    method get-serial-number-string(Device::HIDAPI:D: --> Str:D)

Retrieves the serial number string from the device.

Throws an error if there's a problem getting the data from the device.

method get-indexed-string
-------------------------

    method get-indexed-string(Device::HIDAPI:D: Int:D: $index --> Str)

Given an index, returns the indexed string from the device.

Throws an error if there's a problem getting the data from the device.

DIAGNOSTICS
===========

All exceptions generated by the wrapped hidapi library will be thrown using the `X::Device::HIDAPI` class. The error string set by the `hidapi` library can be found in the `hid-error` attribute (which may be undefined in certain cases, which will show up as "unknown error" in the exception message). The `where` attribute on the exception will name the `hidapi` function that was called that caused the error.

MORE INFORMATION
================

If you want more detail regarding how each of the methods in this interface work. You should see the documentation of the wrapped library here:

  * [https://github.com/libusb/hidapi](https://github.com/libusb/hidapi)

The methods of this interface all map into functions in the original C library with one-to-one correspondance. It should be clear which methods call which function.

INSTALLATION
============

To install this library, you will first need to install the C library. See the latest instructions at the hidapi project page here:

  * [https://github.com/libusb/hidapi](https://github.com/libusb/hidapi)

If you install a pre-packaged binary, make sure it's a development package that includes all the headers as well as the libraries (on Debian-type Linuxes, this means the package iwth the `-dev` suffix).

Once installed, this can be installed like any other Perl 6 module:

    zef install Device::HIDAPI

That should work on Linux, Mac, and Windows.

