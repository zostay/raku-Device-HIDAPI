use v6;

use Device::HIDAPI;

for Device::HIDAPI.enumerate(0, 0) {
    say "Device Found";
    say "  type:          {.vendor-id.fmt('%04x')} {.product-id.fmt('%04x')}";
    say "  path:          {.path}";
    say "  serial-number: {.serial-number}";
    say "  Manufacturer:  {.manufacturer-string}";
    say "  Product:       {.product-string}";
    say "  Release:       {.release-number.fmt('%x')}";
    say "  Interface:     {.interface-number}";
    say "";
}
