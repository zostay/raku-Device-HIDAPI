use v6;
use NativeCall;
sub hid_init(--> int32) is native('hidapi') { * }
hid_init();
