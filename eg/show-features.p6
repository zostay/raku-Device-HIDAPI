use v6;

use Device::HIDAPI;

sub show-features(Device::HIDAPI $dev) {
    my $data = $dev.get-feature-report;
    .fmt("%02X ").print for $data.list;
    say "";
}

multi MAIN(Str $path) {
    my $hid = Device::HIDAPI.new(:$path);
    show-features($hid);
}

multi MAIN(Int $vendor-id, Int $product-id) {
    my $hid = Device::HIDAPI.new(:$vendor-id, :$product-id);
    show-features($hid);
}
