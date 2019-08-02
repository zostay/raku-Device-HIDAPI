use v6;

use Device::HIDAPI;

# This will show at least some of the input from an Xbox One Controller.

sub show-reports($dev) {
    loop {
        my $data = $dev.read;

        my $buttons = $data.read-uint16(2);

        my $ltrigger = $data.read-uint8(4);
        my $rtrigger = $data.read-uint8(5);

        my $lsx = $data.read-int16(6);
        my $lsy = $data.read-int16(8);

        my $rsx = $data.read-int16(10);
        my $rsy = $data.read-int16(12);

        my $up    = ?($buttons +& 0x0001);
        my $down  = ?($buttons +& 0x0002);
        my $left  = ?($buttons +& 0x0004);
        my $right = ?($buttons +& 0x0008);
        my $menu  = $buttons +& 0x0010 ?? "\c[trigram for heaven]" !! ' ';
        my $view  = ?($buttons +& 0x0020) ?? "\c[lower right drop-shadowed white square]" !! ' ';
        my $lbump = $buttons +& 0x0100 ?? "\c[leftwards arrow]" !! ' ';
        my $rbump = $buttons +& 0x0200 ?? "\c[rightwards arrow]" !! ' ';
        my $xboxb = ?($buttons +& 0x0400) ?? "\c[heavy ballot x]" !! ' ';
        my $butta = ?($buttons +& 0x1000) ?? 'A' !! ' ';
        my $buttb = ?($buttons +& 0x2000) ?? 'B' !! ' ';
        my $buttx = ?($buttons +& 0x4000) ?? 'X' !! ' ';
        my $butty = ?($buttons +& 0x8000) ?? 'Y' !! ' ';

        my $ud = $up    ?? "\c[upwards arrow]"    !!
                 $down  ?? "\c[downwards arrow]"  !!
                           ' ';
        my $lr = $left  ?? "\c[leftwards arrow]"  !!
                 $right ?? "\c[rightwards arrow]" !!
                           ' ';

        say qq:to/END_OF_STATUS/;
            Left: $lsx.fmt('%6d') $lsy.fmt('%6d')
           Right: $lsx.fmt('%6d') $lsy.fmt('%6d')
        Triggers: $ltrigger.fmt('%6d') $rtrigger.fmt('%6d')
             Pad: $ud$lr
         Bumpers: $lbump$rbump
         Buttons: $menu$view$xboxb$butta$buttb$buttx$butty
        END_OF_STATUS
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
