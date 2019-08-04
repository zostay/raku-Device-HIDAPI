use v6;

use Device::HIDAPI;

# The reason I built this library is to interface with devices running
# Microsoft's MakeCode firmware, specifically an Adafruit Circuit Playground
# Express. This firmware communicates via a one-off HID protocol called HF2,
# whose definition you can find here:
#
# https://github.com/Microsoft/uf2/blob/master/hf2.md
#
# This is a proof-of-concept implementation showing that I can use HIDAPI to
# communicate with the Adafruit CPX to perform actions like retrieve the console
# log, reset the device, etc.

constant BININFO               = 0x0001;
constant RESET-INTO-APP        = 0x0003;
constant RESET-INTO            = 0x0004;
constant START-FLASH           = 0x0005;

my Bool $DEBUG = False;
my Int $tag = 0;

class Command {
    has $.command-id;
    has $.data;

    multi method new($command-id) {
        self.bless(:$command-id);
    }

    multi method new($command-id, $data) {
        self.bless(:$command-id, :$data);
    }

    method write-to($dev --> Int) {
        my buf8 $buf .= new;
        $buf.write-uint32(0, $.command-id, LittleEndian);
        $buf.write-uint16(4, ++$tag, LittleEndian);
        $buf.write-uint8(6, 0);
        $buf.write-uint8(7, 0);
        $buf.append($.data.Buf) with $.data;

        while $buf.bytes > 63 {
            my $this-buf = $buf.subbuf-rw(0, 63) = blob8.new;
            $this-buf.prepend(63);

            say "SEND $this-buf.map({ .fmt('%02x') })" if $DEBUG;
            $dev.write: $this-buf;
        }

        $buf.prepend(0x40 +| $buf.bytes);
        say "SEND $buf.map({ .fmt('%02x') })" if $DEBUG;
        $dev.write: $buf;

        $tag;
    }
}

class Response {
    has $.tag;
    has $.status;
    has $.status-info;

    has $.data;

    has Bool $.stderr;
    has Bool $.stdout;

    method !read-all-from($dev, :$serial) {
        my $buf = Buf.new($dev.read);
        my $control = $buf.shift;

        # Serial responses only have a single packet, whereas command responses
        # may have 0 or more inner packets followed by a single final packet.
        my $final   = $serial || ?($control +& 0x40);

        # These flags are for serial responses only and are meaningless
        # otherwise.
        # $!stderr  = ($control +& 0xC0 == 0xC0);
        # $!stdout  = ($control +& 0xC0 == 0x80);

        until $final {
            my $next-buf = Buf.new($dev.read);
            my $control  = $buf.shift;
            $final = ?($control +& 0x40);

            $buf.append: $next-buf;
        }

        $buf;
    }

    multi method read-from($dev) {
        my $buf = self!read-all-from($dev);
        self.from-read($buf);
    }

    multi method read-from(\Type, $dev) {
        my $buf = self!read-all-from($dev);
        self.from-read(Type, $buf);
    }

    multi method from-read($buf) {
        say "RECV $buf.map({ .fmt('%02x') })" if $DEBUG;

        my $tag         = $buf.read-uint16(0, LittleEndian);
        my $status      = $buf.read-uint8(2, LittleEndian);
        my $status-info = $buf.read-uint8(3, LittleEndian);

        die "command not understood by device"  if $status == 0x01;
        die "command execution error on device" if $status == 0x02;

        Response.new(:$tag, :$status, :$status-info);
    }

    method !set-data($data) {
        $!data = $data;
    }

    multi method from-read(\Data, $buf) {
        my $response = self.from-read($buf);

        my $data = Data.from-read($buf.subbuf(4));
        $response!set-data($data);

        $response;
    }
}

class BinInfo {
    has $.mode;
    has $.flash-page-size;
    has $.flash-num-pages;
    has $.max-message-size;
    has $.family-id;

    method from-read($buf) {
        my $mode             = $buf.read-uint32(0, LittleEndian);
        my $flash-page-size  = $buf.read-uint32(4, LittleEndian);
        my $flash-num-pages  = $buf.read-uint32(8, LittleEndian);
        my $max-message-size = $buf.read-uint32(12, LittleEndian);
        my $family-id        = $buf.read-uint32(16, LittleEndian);

        self.new(:$mode, :$flash-page-size, :$flash-num-pages, :$max-message-size, :$family-id);
    }
}

sub bininfo($dev) {
    Command.new(BININFO).write-to($dev);
    my $bininfo = Response.read-from(BinInfo, $dev);

    say "";
    say "Mode:             $bininfo.data.mode()";
    say "Flash Page Size:  $bininfo.data.flash-page-size()";
    say "Flash Num Pages:  $bininfo.data.flash-num-pages()";
    say "Max Message Size: $bininfo.data.max-message-size()";
    say "Family ID:        $bininfo.data.family-id()";
    say "";
}

sub reset-to-app($dev) {
    Command.new(RESET-INTO-APP).write-to($dev);
    say "\nReset to app.\n";
}

sub reset-to-bootloader($dev) {
    Command.new(RESET-INTO).write-to($dev);
    say "\nReset to bootloader.\n";
}

sub menu-prompt(--> Str) {
    loop {
        say q:to/END_OF_MENU/;
        Choose one of the following:
        - [B] BININFO
        - [A] Reset into app
        - [L] Reset into bootloader
        - [Q] Quit.
        END_OF_MENU

        print "---> ";
        my $c = $*IN.get.uc;

        return $c if $c eq 'A' | 'B' | 'L' | 'Q';
    }
}

sub main-loop(Str $product) {
    my $dev;
    RELOAD: loop {
        with $dev {
            say "Closing HID.";
            $dev.close;
            $dev = Nil;
        }

        my $info = Device::HIDAPI.enumerate.first({
            .product-string.starts-with($product)
        });

        without $info {
            sleep 1;
            next;
        }

        say "Opening HID [$info.path()].";
        until $dev.defined {
            $dev = try Device::HIDAPI.new(path => $info.path);
            sleep 1;
        }

        while menu-loop($dev) {
            next RELOAD;
        }

        say "Closing HID. Quitting.";
        $dev.close;
        last;
    }
}

sub menu-loop(Device::HIDAPI $dev --> Bool) {
    loop {
        given menu-prompt() {
            when 'B' { bininfo($dev) }
            when 'A' { reset-to-app($dev); return True }
            when 'L' { reset-to-bootloader($dev); return True }
            when 'Q' { return False }
        }
    }
}

sub MAIN(Str :$product = "CPlay Express", Bool :$debug = False) {
    $DEBUG = $debug;
    main-loop($product);
}
