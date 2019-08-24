use v6;

use NativeCall;

unit class Device::HIDAPI is repr('CPointer');

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

#		struct hid_device_;
#		typedef struct hid_device_ hid_device; /**< opaque hidapi structure */
#
#		/** hidapi info structure */
#		struct hid_device_info {
#			/** Platform-specific device path */
#			char *path;
#			/** Device Vendor ID */
#			unsigned short vendor_id;
#			/** Device Product ID */
#			unsigned short product_id;
#			/** Serial Number */
#			wchar_t *serial_number;
#			/** Device Release Number in binary-coded decimal,
#			    also known as Device Version Number */
#			unsigned short release_number;
#			/** Manufacturer String */
#			wchar_t *manufacturer_string;
#			/** Product string */
#			wchar_t *product_string;
#			/** Usage Page for this Device/Interface
#			    (Windows/Mac only). */
#			unsigned short usage_page;
#			/** Usage for this Device/Interface
#			    (Windows/Mac only).*/
#			unsigned short usage;
#			/** The USB interface which this logical device
#			    represents.
#
#				* Valid on both Linux implementations in all cases.
#				* Valid on the Windows implementation only if the device
#				  contains more than one interface.
#				* Valid on the Mac implementation if and only if the device
#				  is a USB HID device. */
#			int interface_number;
#
#			/** Pointer to the next device */
#			struct hid_device_info *next;
#		};
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

#		/** @brief Initialize the HIDAPI library.
#
#			This function initializes the HIDAPI library. Calling it is not
#			strictly necessary, as it will be called automatically by
#			hid_enumerate() and any of the hid_open_*() functions if it is
#			needed.  This function should be called at the beginning of
#			execution however, if there is a chance of HIDAPI handles
#			being opened by different threads simultaneously.
#
#			@ingroup API
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT HID_API_CALL hid_init(void);
sub hid_init(--> int32) is native(HIDAPI) { * }
BEGIN hid_init() == 0 or die "unable to initialie hidapi";

#		/** @brief Finalize the HIDAPI library.
#
#			This function frees all of the static data associated with
#			HIDAPI. It should be called at the end of execution to avoid
#			memory leaks.
#
#			@ingroup API
#
#		    @returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT HID_API_CALL hid_exit(void);
sub hid_exit(--> int32) is native(HIDAPI) { * }
END hid_exit() == 0 or die "unable to finalize hidapi";

#		/** @brief Enumerate the HID Devices.
#
#			This function returns a linked list of all the HID devices
#			attached to the system which match vendor_id and product_id.
#			If @p vendor_id is set to 0 then any vendor matches.
#			If @p product_id is set to 0 then any product matches.
#			If @p vendor_id and @p product_id are both set to 0, then
#			all HID devices will be returned.
#
#			@ingroup API
#			@param vendor_id The Vendor ID (VID) of the types of device
#				to open.
#			@param product_id The Product ID (PID) of the types of
#				device to open.
#
#		    @returns
#		    	This function returns a pointer to a linked list of type
#		    	struct #hid_device_info, containing information about the HID devices
#		    	attached to the system, or NULL in the case of failure. Free
#		    	this linked list by calling hid_free_enumeration().
#		*/
#		struct hid_device_info HID_API_EXPORT * HID_API_CALL hid_enumerate(unsigned short vendor_id, unsigned short product_id);
sub hid_enumerate(uint16 $vendor-id, uint16 $product-id --> Pointer[InternalDeviceInfo]) is native(HIDAPI) { * }

#		/** @brief Free an enumeration Linked List
#
#		    This function frees a linked list created by hid_enumerate().
#
#			@ingroup API
#		    @param devs Pointer to a list of struct_device returned from
#		    	      hid_enumerate().
#		*/
#		void  HID_API_EXPORT HID_API_CALL hid_free_enumeration(struct hid_device_info *devs);
sub hid_free_enumeration(Pointer[InternalDeviceInfo] $devs) is native(HIDAPI) { * }

method enumerate(::?CLASS: UInt $vendor-id = 0, UInt $product-id = 0 --> Seq) {
    gather {
        my $dev-info-ptr = hid_enumerate($vendor-id, $product-id);

        loop (my $dev-ptr = $dev-info-ptr; $dev-ptr; $dev-ptr = $dev-ptr.next) {
            my $dev-info = nativecast(InternalDeviceInfo, $dev-ptr);
            take DeviceInfo.new($dev-info);
        }

        hid_free_enumeration($dev-info-ptr);
    }
}

#		/** @brief Open a HID device using a Vendor ID (VID), Product ID
#			(PID) and optionally a serial number.
#
#			If @p serial_number is NULL, the first device with the
#			specified VID and PID is opened.
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param vendor_id The Vendor ID (VID) of the device to open.
#			@param product_id The Product ID (PID) of the device to open.
#			@param serial_number The Serial Number of the device to open
#				               (Optionally NULL).
#
#			@returns
#				This function returns a pointer to a #hid_device object on
#				success or NULL on failure.
#		*/
#		HID_API_EXPORT hid_device * HID_API_CALL hid_open(unsigned short vendor_id, unsigned short product_id, const wchar_t *serial_number);
sub hid_open(uint16 $vendor-id, uint16 $product-id, Str $serial-number --> Device::HIDAPI) is native(HIDAPI) { * }

method !error($where) {
    my $error = hid_error(self) // 'unknown error';
    die "$where: $error";
}

method !try-error($where) {
    my $error = hid_error(self);
    die "$where: $error" with $error;
}

multi method new(::?CLASS:U: UInt :$vendor-id!, UInt :$product-id!, Str :$serial-number --> Device::HIDAPI) {
    my $dev = hid_open($vendor-id, $product-id, $serial-number);
    without $dev {
        self!error('hid_open');
    }
    $dev;
}

#		/** @brief Open a HID device by its path name.
#
#			The path name be determined by calling hid_enumerate(), or a
#			platform-specific path name can be used (eg: /dev/hidraw0 on
#			Linux).
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#		    @param path The path name of the device to open
#
#			@returns
#				This function returns a pointer to a #hid_device object on
#				success or NULL on failure.
#		*/
#		HID_API_EXPORT hid_device * HID_API_CALL hid_open_path(const char *path);
sub hid_open_path(Str $path --> Device::HIDAPI) is native(HIDAPI) { * }

multi method new(::?CLASS:U: Str:D :$path! --> Device::HIDAPI) {
    my $dev = hid_open_path($path);
    without $dev {
        self!error('hid_open_path');
    }
    $dev;
}

#		/** @brief Write an Output report to a HID device.
#
#			The first byte of @p data[] must contain the Report ID. For
#			devices which only support a single report, this must be set
#			to 0x0. The remaining bytes contain the report data. Since
#			the Report ID is mandatory, calls to hid_write() will always
#			contain one more byte than the report contains. For example,
#			if a hid report is 16 bytes long, 17 bytes must be passed to
#			hid_write(), the Report ID (or 0x0, for devices with a
#			single report), followed by the report data (16 bytes). In
#			this example, the length passed in would be 17.
#
#			hid_write() will send the data on the first OUT endpoint, if
#			one exists. If it does not, it will send the data through
#			the Control Endpoint (Endpoint 0).
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param data The data to send, including the report number as
#				the first byte.
#			@param length The length in bytes of the data to send.
#
#			@returns
#				This function returns the actual number of bytes written and
#				-1 on error.
#		*/
#		int  HID_API_EXPORT HID_API_CALL hid_write(hid_device *dev, const unsigned char *data, size_t length);
sub hid_write(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method write(::?CLASS:D: blob8 $data --> UInt) {
    my CArray[uint8] $hid-data = CArray[uint8].new($data.list);

    my $bytes-written = hid_write(self, $hid-data, $data.elems);
    if $bytes-written < 0 {
        self!error('hid_write');
    }

    $bytes-written;
}

#		/** @brief Read an Input report from a HID device with timeout.
#
#			Input reports are returned
#			to the host through the INTERRUPT IN endpoint. The first byte will
#			contain the Report number if the device uses numbered reports.
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param data A buffer to put the read data into.
#			@param length The number of bytes to read. For devices with
#				multiple reports, make sure to read an extra byte for
#				the report number.
#			@param milliseconds timeout in milliseconds or -1 for blocking wait.
#
#			@returns
#				This function returns the actual number of bytes read and
#				-1 on error. If no packet was available to be read within
#				the timeout period, this function returns 0.
#		*/
#		int HID_API_EXPORT HID_API_CALL hid_read_timeout(hid_device *dev, unsigned char *data, size_t length, int milliseconds);
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

#		/** @brief Read an Input report from a HID device.
#
#			Input reports are returned
#		    to the host through the INTERRUPT IN endpoint. The first byte will
#			contain the Report number if the device uses numbered reports.
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param data A buffer to put the read data into.
#			@param length The number of bytes to read. For devices with
#				multiple reports, make sure to read an extra byte for
#				the report number.
#
#			@returns
#				This function returns the actual number of bytes read and
#				-1 on error. If no packet was available to be read and
#				the handle is in non-blocking mode, this function returns 0.
#		*/
#		int  HID_API_EXPORT HID_API_CALL hid_read(hid_device *dev, unsigned char *data, size_t length);
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

#		/** @brief Set the device handle to be non-blocking.
#
#			In non-blocking mode calls to hid_read() will return
#			immediately with a value of 0 if there is no data to be
#			read. In blocking mode, hid_read() will wait (block) until
#			there is data to read before returning.
#
#			Nonblocking can be turned on and off at any time.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param nonblock enable or not the nonblocking reads
#			 - 1 to enable nonblocking
#			 - 0 to disable nonblocking.
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int  HID_API_EXPORT HID_API_CALL hid_set_nonblocking(hid_device *dev, int nonblock);
sub hid_set_nonblocking(Device::HIDAPI $dev, int32 $nonblock --> int32) is native(HIDAPI) { * }

method set-nonblocking(::?CLASS:D: Bool:D $nonblock) {
    if hid_set_nonblocking(self, +$nonblock) < 0 {
        self!error('hid_set_nonblocking');
    }
}

#		/** @brief Send a Feature report to the device.
#
#			Feature reports are sent over the Control endpoint as a
#			Set_Report transfer.  The first byte of @p data[] must
#			contain the Report ID. For devices which only support a
#			single report, this must be set to 0x0. The remaining bytes
#			contain the report data. Since the Report ID is mandatory,
#			calls to hid_send_feature_report() will always contain one
#			more byte than the report contains. For example, if a hid
#			report is 16 bytes long, 17 bytes must be passed to
#			hid_send_feature_report(): the Report ID (or 0x0, for
#			devices which do not use numbered reports), followed by the
#			report data (16 bytes). In this example, the length passed
#			in would be 17.
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param data The data to send, including the report number as
#				the first byte.
#			@param length The length in bytes of the data to send, including
#				the report number.
#
#			@returns
#				This function returns the actual number of bytes written and
#				-1 on error.
#		*/
#		int HID_API_EXPORT HID_API_CALL hid_send_feature_report(hid_device *dev, const unsigned char *data, size_t length);
sub hid_send_feature_report(Device::HIDAPI $dev, CArray[uint8] $data, size_t $length --> int32) is native(HIDAPI) { * }

method send-feature-report(::?CLASS:D: blob8 $data --> UInt) {
    my CArray[uint8] $buf .= new($data.list);

    my $bytes-written = hid_send_feature_report(self, $buf, $buf.elems);
    if $bytes-written < 0 {
        self!error('hid_send_feature_report');
    }

    $bytes-written;
}

#		/** @brief Get a feature report from a HID device.
#
#			Set the first byte of @p data[] to the Report ID of the
#			report to be read.  Make sure to allow space for this
#			extra byte in @p data[]. Upon return, the first byte will
#			still contain the Report ID, and the report data will
#			start in data[1].
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param data A buffer to put the read data into, including
#				the Report ID. Set the first byte of @p data[] to the
#				Report ID of the report to be read, or set it to zero
#				if your device does not use numbered reports.
#			@param length The number of bytes to read, including an
#				extra byte for the report ID. The buffer can be longer
#				than the actual report.
#
#			@returns
#				This function returns the number of bytes read plus
#				one for the report ID (which is still in the first
#				byte), or -1 on error.
#		*/
#		int HID_API_EXPORT HID_API_CALL hid_get_feature_report(hid_device *dev, unsigned char *data, size_t length);
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

#		/** @brief Close a HID device.
#
#			This function sets the return value of hid_error().
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#		*/
#		void HID_API_EXPORT HID_API_CALL hid_close(hid_device *dev);
sub hid_close(Device::HIDAPI $dev) is native(HIDAPI) { * }

method close(::?CLASS:D:) {
    hid_close(self);
    self!try-error('hid_close');
}

submethod DESTROY(::?CLASS:D:) {
    hid_close(self);
    self!try-error('hid_close');
}

#		/** @brief Get The Manufacturer String from a HID device.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param string A wide string buffer to put the data into.
#			@param maxlen The length of the buffer in multiples of wchar_t.
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT_CALL hid_get_manufacturer_string(hid_device *dev, wchar_t *string, size_t maxlen);
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

#		/** @brief Get The Product String from a HID device.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param string A wide string buffer to put the data into.
#			@param maxlen The length of the buffer in multiples of wchar_t.
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT_CALL hid_get_product_string(hid_device *dev, wchar_t *string, size_t maxlen);
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

#		/** @brief Get The Serial Number String from a HID device.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param string A wide string buffer to put the data into.
#			@param maxlen The length of the buffer in multiples of wchar_t.
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT_CALL hid_get_serial_number_string(hid_device *dev, wchar_t *string, size_t maxlen);
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

#		/** @brief Get a string from a HID device, based on its string index.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open().
#			@param string_index The index of the string to get.
#			@param string A wide string buffer to put the data into.
#			@param maxlen The length of the buffer in multiples of wchar_t.
#
#			@returns
#				This function returns 0 on success and -1 on error.
#		*/
#		int HID_API_EXPORT_CALL hid_get_indexed_string(hid_device *dev, int string_index, wchar_t *string, size_t maxlen);
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

#		/** @brief Get a string describing the last error which occurred.
#
#			Whether a function sets the last error is noted in its
#			documentation. These functions will reset the last error
#			to NULL before their execution.
#
#			Strings returned from hid_error() must not be freed by the user!
#
#			This function is thread-safe, and error messages are thread-local.
#
#			@ingroup API
#			@param dev A device handle returned from hid_open(),
#			  or NULL to get the last non-device-specific error
#			  (e.g. for errors in hid_open() itself).
#
#			@returns
#				This function returns a string containing the last error
#				which occurred or NULL if none has occurred.
#		*/
#		HID_API_EXPORT const wchar_t* HID_API_CALL hid_error(hid_device *dev);
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
