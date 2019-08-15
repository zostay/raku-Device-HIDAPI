use v6;
use NativeCall;
sub hid_init(--> int32) is native('hidapi-hidraw') { * }
hid_init();
