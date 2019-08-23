use v6;

constant LIBS = <hidapi hidapi-hidraw hidapi-libusb>;

class Build {
    method try-libraries($workdir --> Seq) {
        gather for LIBS -> $try-lib {
            $*ERR.print: "Trying to use native library $try-lib: ";
            try {
                EVALFILE "$workdir/test/$try-lib.p6";
                $*ERR.say: "found";
                take $try-lib;

                CATCH {
                    default {
                        $*ERR.say: "failed: $_";
                    }
                }
            }
        }
    }

    method find-library($workdir --> Str) {
        my @libs = self.try-libraries($workdir);
        @libs ?? @libs.first !! die "no hidapi library found, is it installed?";
    }

    method build($workdir) {
        my $lib = self.find-library($workdir);
        mkdir "$workdir/lib/Device/HIDAPI";
        "$workdir/lib/Device/HIDAPI/Config.pm6".IO.spurt(qq:to/END_OF_CONFIG/);
            # DO NOT EDIT. This file is auto-generated.
            use v6;

            unit package Device::HIDAPI::Config;

            our constant \$HIDAPI = q[$lib];
            END_OF_CONFIG
    }
}
