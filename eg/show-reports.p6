use v6;

use Device::HIDAPI;

sub show-reports(Device::HIDAPI $dev) {
    loop {
        my $data = $dev.read;
        .fmt("%02X ").print for $data.list;
        say "";
    }
}

multi MAIN(Str $path) {
    my $hid = Device::HIDAPI.new(:$path);
    show-reports($hid);
}

multi MAIN(Int $vendor-id, Int $product-id) {
    my $hid = Device::HIDAPI.new(:$vendor-id, :$product-id);
    show-reports($hid);
}
