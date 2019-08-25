use v6;

use NativeCall;

unit class Device::HIDAPI:ver<0.0.0>:auth<github:zostay> is repr('CPointer');

my sub HIDAPI-Config(--> Str:D) {
    try require ::('Device::HIDAPI::Config');
    if ::('Device::HIDAPI::Config') ~~ Failure {
        'hidapi'
    }
    else {
        $::('Device::HIDAPI::Config::HIDAPI');
    }
}

constant HIDAPI = HIDAPI-Config;

#| hidapi info structure from C
my class InternalDeviceInfo is repr('CStruct') {
    has Str $.path;
    has uint16 $!vendor-id;
    has uint16 $!product-id;
    has CArray[uint32] $!serial-number;
    has uint16 $!release-number;
    has CArray[uint32] $!manufacturer-string;
    has CArray[uint32] $!product-string;
    has uint16 $!usage-page;
    has uint16 $!usage;
    has uint32 $!interface-number;
    has Pointer $.next;

    # So... For reasons (it's a bug) uint16 apparently can be read as an int
    # instead of a uint. In those cases a value like 65280 will appear
    # instead as -256. This uses 2's compliment to undo that when that
    # happens. This is definitely a rakudobug. I've been told it's known,
    # but I don't have a bug number for it. Someday, though...
    #
    # TODO Remove this work-around to uint16 and negative values bug.
    # (preferably after rakudo fixes the bug)
    my sub convert-uint-to-uint($v) {
        $v < 0 ?? +^$v !! $v
    }

    my sub convert-wide-string($array) {
        my $length = 0;
        my @chrs = gather loop {
            die "something went wrong decoding HID API string"
                if $length >= 1024;

            last if $array.AT-POS($length) == 0;
            take $array.AT-POS($length++);
        }

        chrs(@chrs);
    }

    method vendor-id(--> uint16) { convert-uint-to-uint($!vendor-id) }
    method product-id(--> uint16) { convert-uint-to-uint($!product-id) }
    method serial-number(--> Str) { convert-wide-string($!serial-number) }
    method release-number(--> uint16) { convert-uint-to-uint($!release-number) }
    method manufacturer-string(--> Str) { convert-wide-string($!manufacturer-string) }
    method product-string(--> Str) { convert-wide-string($!product-string) }
    method usage-page(--> uint16) { convert-uint-to-uint($!usage-page) }
    method usage(--> uint16) { convert-uint-to-uint($!usage) }
    method interface-number(--> uint32) { convert-uint-to-uint($!interface-number) }
}

#| The hidapi device info structure provided to Perl 6 callers
class DeviceInfo {
    has Str $.path;
    has UInt $.vendor-id;
    has UInt $.product-id;
    has Str $.serial-number;
    has UInt $.release-number;
    has Str $.manufacturer-string;
    has Str $.product-string;
    has UInt $.usage-page;
    has UInt $.usage;
    has UInt $.interface-number;

    only method new(InternalDeviceInfo $dev-info) {
        self.bless(
            path                => $dev-info.path,
            vendor-id           => $dev-info.vendor-id,
            product-id          => $dev-info.product-id,
            serial-number       => $dev-info.serial-number,
            release-number      => $dev-info.release-number,
            manufacturer-string => $dev-info.manufacturer-string,
            product-string      => $dev-info.product-string,
            usage-page          => $dev-info.usage-page,
            usage               => $dev-info.usage,
            interface-number    => $dev-info.interface-number,
        );
    }
}

#| Initialize the HIDAPI library.
sub hid_exit(--> int32) is native(HIDAPI) { * }
END hid_exit() == 0 or die "unable to finalize hidapi";

#| Enumerate the HID Devices
sub hid_enumerate(uint16 $vendor-id, uint16 $product-id --> Pointer[InternalDeviceInfo]) is native(HIDAPI) { * }

#| Free an enumeration Linked List
sub hid_free_enumeration(Pointer[InternalDeviceInfo] $devs) is native(HIDAPI) { * }

method enumerate(::?CLASS: UInt $vendor-id = 0, UInt $product-id = 0 --> Seq) {
    gather {
        my $dev-info-ptr = hid_enumerate($vendor-id, $product-id);

        my $dev-info;
        loop (my $dev-ptr = $dev-info; $dev-ptr; $dev-ptr = $dev-info.next) {
            $dev-info = nativecast(InternalDeviceInfo, $dev-ptr);
            take DeviceInfo.new($dev-info);
        }

        hid_free_enumeration($dev-info-ptr);
    }
}

#| Open a HID device using a Vendor ID (VID, Product ID (PID) and optionally a
#| serial number.
sub hid_open(uint16 $vendor-id, uint16 $product-id, Str $serial-number --> Device::HIDAPI) is native(HIDAPI) { * }

class GLOBAL::X::Device::HIDAPI is Exception {
    has Str $.where;
    has Str $.hid-error;

    method hid-error-or-unknown() { $.hid-error // 'unknown error' }
    method message(--> Str:D) { "$.where: $.hid-error-or-unknown" }
}

method !error($where) {
    my $hid-error = hid_error(self);
    die X::Device::HIDAPI.new(:$where, :$hid-error)
}

method !try-error($where) {
    my $hid-error = hid_error(self);
    die X::Device::HIDAPI.new(:$where, $hid-error) with $hid-error;
}

multi method new(::?CLASS:U: UInt :$vendor-id!, UInt :$product-id!, Str :$serial-number --> Device::HIDAPI) {
    my $dev = hid_open($vendor-id, $product-id, $serial-number);
    without $dev {
        self!error('hid_open');
    }
    $dev;
}

#| Open a HID device by its path name.
sub hid_open_path(Str $path --> Device::HIDAPI) is native(HIDAPI) { * }

multi method new(::?CLASS:U: Str:D :$path! --> Device::HIDAPI) {
    my $dev = hid_open_path($path);
    without $dev {
        self!error('hid_open_path');
    }
    $dev;
}

#| Write an Output report to a HID device.
sub hid_write(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method write(::?CLASS:D: blob8 $data --> UInt) {
    my CArray[uint8] $hid-data = CArray[uint8].new($data.list);

    my $bytes-written = hid_write(self, $hid-data, $data.elems);
    if $bytes-written < 0 {
        self!error('hid_write');
    }

    $bytes-written;
}

#| Read an Input report from a HID device with timeout.
sub hid_read_timeout(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length, uint32 $milliseconds --> int32) is native(HIDAPI) { * }

my constant BUFFER_SIZE = 256;

method read-timeout(::?CLASS:D: UInt $milliseconds --> blob8:D) {
    my CArray[uint8] $buf .= new;
    $buf[ BUFFER_SIZE - 1 ] = 0;

    my $bytes-read = hid_read_timeout(self, $buf, BUFFER_SIZE, $milliseconds);

    if $bytes-read < 0 {
        self!error('hid_read_timeout');
    }

    blob8.new($buf.list[^$bytes-read]);
}

#| Read an Input report from a HID device.
sub hid_read(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method read(::?CLASS:D: --> blob8:D) {
    my CArray[uint8] $buf .= new;
    $buf[ BUFFER_SIZE - 1 ] = 0;
    my $bytes-read = hid_read(self, $buf, BUFFER_SIZE);

    if $bytes-read < 0 {
        self!error('hid_read');
    }

    blob8.new($buf.list[^$bytes-read]);
}

#| Set the device handle to be non-blocking.
sub hid_set_nonblocking(Device::HIDAPI $dev, int32 $nonblock --> int32) is native(HIDAPI) { * }

method set-nonblocking(::?CLASS:D: Bool:D $nonblock) {
    if hid_set_nonblocking(self, +$nonblock) < 0 {
        self!error('hid_set_nonblocking');
    }
}

#| Send a Feature report to the device.
sub hid_send_feature_report(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method send-feature-report(::?CLASS:D: blob8 $data --> UInt) {
    my CArray[uint8] $buf .= new($data.list);

    my $bytes-written = hid_send_feature_report(self, $buf, $buf.elems);
    if $bytes-written < 0 {
        self!error('hid_send_feature_report');
    }

    $bytes-written;
}

#| Get a feature report from a HID device.
sub hid_get_feature_report(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method get-feature-report(::?CLASS:D: --> blob8) {
    my CArray[uint8] $buf .= new;
    $buf[ BUFFER_SIZE - 1] = 0;

    my $bytes-read = hid_get_feature_report(self, $buf, BUFFER_SIZE);
    if $bytes-read < 0 {
        self!error('hid_get_feature_report');
    }

    blob8.new($buf.list[^$bytes-read]);
}

#| Close a HID device.
sub hid_close(Device::HIDAPI $dev) is native(HIDAPI) { * }

method close(::?CLASS:D:) {
    hid_close(self);
    self!try-error('hid_close');
}

submethod DESTROY(::?CLASS:D:) {
    hid_close(self);
    self!try-error('hid_close');
}

#| Get The Manufacturer String from a HID device.
sub hid_get_manufacturer_string(Device::HIDAPI $dev, CArray[int32] $string, size_t $maxlen --> int32) is native(HIDAPI) { * }

my constant STRING_SIZE = 256;

method get-manufacturer-string(::?CLASS:D: --> Str:D) {
    my CArray[int32] $chrs .= new;
    $chrs[ STRING_SIZE - 1 ] = 0;

    my $actual-size = hid_get_manufacturer_string(self, $chrs, STRING_SIZE);
    if $actual-size < 0 {
        self!error('hid_get_manufacturer_string');
    }

    chrs($chrs.list[^$actual-size]);
}

#| Get The Product String from a HID device.
sub hid_get_product_string(Device::HIDAPI $dev, CArray[int32] $string, size_t $maxlen --> int32) is native(HIDAPI) { * }

method get-product-string(::?CLASS:D: --> Str:D) {
    my CArray[int32] $chrs .= new;
    $chrs[ STRING_SIZE - 1 ] = 0;

    my $actual-size = hid_get_product_string(self, $chrs, STRING_SIZE);
    if $actual-size < 0 {
        self!error('hid_get_product_string');
    }

    chrs($chrs.list[^$actual-size]);
}

#| Get The Serial Number String from a HID device.
sub hid_get_serial_number_string(Device::HIDAPI $dev, CArray[int32] $string, size_t $maxlen --> int32) is native(HIDAPI) { * }

method get-serial-number-string(::?CLASS:D: --> Str:D) {
    my CArray[int32] $chrs .= new;
    $chrs[ STRING_SIZE - 1 ] = 0;

    my $actual-size = hid_get_serial_number_string(self, $chrs, STRING_SIZE);
    if $actual-size < 0 {
        self!error('hid_get_serial_number_string');
    }

    chrs($chrs.list[^$actual-size]);
}

#| Get a string from a HID device, based on its string index.
sub hid_get_indexed_string(Device::HIDAPI $dev, int32 $string-index, CArray[int32] $string, size_t $maxlen --> int32) is native(HIDAPI) { * }

method get-indexed-string(::CLASS:D: Int:D $string-index --> Str) {
    my CArray[int32] $chrs .= new;
    $chrs[ STRING_SIZE - 1 ] = 0;

    my $actual-size = hid_get_indexed_string(self, $string-index, $chrs, STRING_SIZE);
    if $actual-size < 0 {
        self!error('hid_get_indexed_string');
    }

    $actual-size == 0 ?? Nil !! chrs($chrs.list[^$actual-size]);
}

#| Get a string describing the last error which occurred.
sub hid_error(Device::HIDAPI $dev --> Str) is native(HIDAPI) { * }

=begin pod

=head1 NAME

Device::HIDAPI - low-level HID interface

=head1 SYNOPSIS

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

=head1 DESCRIPTION

If you need to perform low-level interfacing with a HID (device implementing the Human Interface Device protocol), this library is for you. It depends on a C library named hidapi, which you can get from the libusb project (see INSTALLATION for details).

This is a low-level library, so if you want to interface with a keyboard, mouse, joystick or other standard equipment, there's probably a better way. However, if you have a HID that implements a custom protocol or you need to get to the raw device data for some reason, this library will get you there. It provides a binary interface to read and write data to HIDs.

=head1 CLASSES

=head2 Device::HIDAPI

This class is the primary interface for enumerating devices, All the methods defined under METHODS below belong to this class.

=head2 Device::HIDAPI::Config

This is a special compile-time generated class that configures the library to use. You should never need to do anythign with this yourself.

=head2 Device::HIDAPI::DeviceInfo

Objects of this type are returned by the device enumeration method. It provides the following read-only attributes about each device:

=defn path
This is the OS-specific path for referring to the device.

=defn vendor-id
This is the integer vendor ID for the device.

=defn product-id
This is the integer product ID for the device.

=defn serial-number
This is the string serial number of the device.

=defn release-number
This is integer release number of the device.

=defn manufacturer-string
This is the string naming the manufacturer of the device.

=defn product-string
This is the string naming the product.

=defn usage-page
This is an integer usage page descriptor.

=defn usage
This is an integer usage descriptor.

=defn interface-number
This is the integer interface number.

=head2 X::Device::HIDAPI

This is the exception object used whenever a wrapped C<hidapi> function returns an error. It provides two attributes:

=defn where
This names the C<hidapi> library function that was called when the error was triggered.

=defn hid-error
This is the error message returned by the C<hidapi> library for the error (or an undefined value if the C<hidapi> library returned a C<NULL> value).

=head1 METHODS

=head2 method enumerate

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

The C<$vendor-id> and C<$product-id> can be set to specific numbers to list only devices matching those IDs. A value of 0 (the default) matches all IDs (i.e., list all).

=head2 method new

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

These constructors return an instance of C<Device::HIDAPI>, which can be used to read from and write to the device. You may construct the object either using the C<$vendor-id> and the C<$product-id> or the C<$path> to the device. It is possible to have multiple of the same device connected, in which case you may also want to provide the C<$serial-number> when using the VID and PID.

=head2 method write

    method write(Device::HIDAPI:D: blob8 $data --> UInt:D)

Writes the given blob to the device. Returns the number of bytes actually written.

=head2 method read-timeout

    method read-timeout(Device::HIDAPI:D: UInt:D $millis --> blob8:D)

Reads data from the device or fails with an exception. If the device does not return anything within C<$millis> milliseconds it returns an empty C<Blob>.

Throws an exception if there's an error during the read.

=head2 method read

    method read(Device::HIDAPI:D: --> blob8:D)

Reads data from the device. Unless the object has been set to use non-blocking operations, this operation will block until data becomes available. If non-blocking has been set, then this will return data if any is waiting or return an empty C<Blob> immediately if none is currently ready to read.

Throws an exception if there's an error during the read.

=head2 method set-nonblocking

    method set-nonblocking(Device::HIDAPI:D: Bool:D $nonblock)

Sets the device as non-blocking or not based on the value of C<$nonblock>. If the object is set to non-blocking, then calls to L</method read> will not block.

May throw an exception if an error occurs making a change to the device object.

=head2 method send-feature-report

    method send-feature-report(Device::HIDAPI:D: blob8 $data --> UInt:D)

Sends a feature rreport to the device. Returns the number of bytes written.

Throws an exception if there is an error performing the write.

=head2 method get-feature-report

    method get-feature-report(Device::HIDAPI:D: --> blob8:D)

Retrieve a feature report from the device.

Throws an exception if there is an error performing the read.

=head2 method close

    method close(Device::HIDAPI:D:)

Closes the device and frees up associated resources. You should call this manually after creating the object if you want to make sure resources are freed before the garbage collector gets around to freeing memory:

    # You can make calling this automatic when the variable goes out of scope
    # like this...
    my Device::HIDAPI:D $dev is leave({ .close }) .= new($path);

Throws an error if there is a problem releasing the object.

=head2 method get-manufacturer-string

    method get-manufacturer-string(Device::HIDAPI:D: --> Str:D)

Retrieves the manufacturer string from the device.

Throws an error if there's a problem getting the data from the device.

=head2 method get-product-string

    method get-product-string(Device::HIDAPI:D: --> Str:D)

Retrieves the product string from the device.

Throws an error if there's a problem getting the data from the device.

=head2 method get-serial-number-string

    method get-serial-number-string(Device::HIDAPI:D: --> Str:D)

Retrieves the serial number string from the device.

Throws an error if there's a problem getting the data from the device.

=head2 method get-indexed-string

    method get-indexed-string(Device::HIDAPI:D: Int:D: $index --> Str)

Given an index, returns the indexed string from the device.

Throws an error if there's a problem getting the data from the device.

=head1 DIAGNOSTICS

All exceptions generated by the wrapped hidapi library will be thrown using the C<X::Device::HIDAPI> class. The error string set by the C<hidapi> library can be found in the C<hid-error> attribute (which may be undefined in certain cases, which will show up as "unknown error" in the exception message). The C<where> attribute on the exception will name the C<hidapi> function that was called that caused the error.

=head1 MORE INFORMATION

If you want more detail regarding how each of the methods in this interface work. You should see the documentation of the wrapped library here:

=item L<https://github.com/libusb/hidapi>

The methods of this interface all map into functions in the original C library with one-to-one correspondance. It should be clear which methods call which function.

=head1 INSTALLATION

To install this library, you will first need to install the C library. See the latest instructions at the hidapi project page here:

=item L<https://github.com/libusb/hidapi>

If you install a pre-packaged binary, make sure it's a development package that includes all the headers as well as the libraries (on Debian-type Linuxes, this means the package iwth the  C<-dev> suffix).

Once installed, this can be installed like any other Perl 6 module:

    zef install Device::HIDAPI

That should work on Linux, Mac, and Windows.

=end pod
