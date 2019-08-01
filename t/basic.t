use v6;

use Test;
use Device::HIDAPI;

pass("It compiled. You go this far at least.");

my $got-stuff = False;
for Device::HIDAPI.enumerate(0, 0) {
    pass("Found some stuff.");
    $got-stuff++;
}

if $got-stuff {
    my $hid = Device::HIDAPI.new(:0vendor-id, :0product-id);
    isa-ok $hid, Device::HIDAPI;
}


done-testing;
