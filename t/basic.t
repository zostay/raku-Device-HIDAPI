use v6;

use Test;
use Device::HIDAPI;

say .path for Device::HIDAPI.enumerate(0, 0);

done-testing;
