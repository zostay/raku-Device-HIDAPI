use v6;

use Test;
use Device::HIDAPI;

pass("It compiled. You go this far at least.");

my SetHash[Capture] $got-info .= new;
for Device::HIDAPI.enumerate {
    $got-info{ \(.vendor-id, .product-id) } = True;
    pass("Found some stuff.");
}

for $got-info.keys -> ($vendor-id, $product-id) {
    my $hid = try Device::HIDAPI.new(
        :$vendor-id,
        :$product-id,
    );

    isa-ok $hid, Device::HIDAPI;
}

done-testing;
