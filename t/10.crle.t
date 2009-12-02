#!/perl
use strict;

use Test::More 'no_plan';

use Solaris::CRLE;
my $crle = Solaris::CRLE->new();

my $output_file = 't/crle.output';
open(my $fh, '<', $output_file) or die "Couldn't open $output_file for reading: $!\n";

my @output;
while ( my $line = <$fh> ) { chomp $line; push @output, $line }
close $fh or die "Error closing file: $!\n";

ok( scalar @output,
    "Checking that $output_file was read successfully"
);

ok( $crle->parse_output( @output ),
    'Parsing test crle output file'
);

my %spot_checks
    = ( '/usr/local/lib'                 => [ 'libpangox-1.0.so',
                                              'librrd.so',
                                              'libpng.so.3',
                                              'libcrypto.so',
                                          ],
        '/usr/local/root/jpegsrc.v7/lib' => [  'libjpeg.so.7.0.0' ],
        '/lib'                           => [  'libnwam.so.1',
                                               'libdl.so.1',
                                               'libm.so',
                                               'libssl.so',
                                           ],
        '/usr/lib'                       => [ 'libpangox-1.0.so',
                                              'libsec.so',
                                              'libthread.so.1',
                                          ],
        '/usr/X11/lib'                   => [ 'libXvMC.so.1',
                                              'libXmu.so.4',
                                              'libXi.so.5',
                                          ],
        '/usr/sfw/lib'                   => [ 'libusb.so.1',
                                          ],
    );


for my $directory ( keys %spot_checks ) {
    ok( $crle->libs->{$directory},
        "Checking that directory was found in ld.confing output: $directory"
    );

    for my $lib ( @{ $spot_checks{$directory} } ) {
        ok( $crle->libs->{$directory}->{$lib},
            "Checking that $directory contains $lib"
        );
    }
}

is_deeply( $crle->default_library_path,
           [ '/usr/local/lib', '/lib', '/usr/lib' ],
           'Checking default library path'
       );

is_deeply( $crle->trusted_directories,
           [ '/lib/secure', '/usr/lib/secure' ],
           'Checking trusted directories'
       );

is( $crle->command,
    'crle -c /usr/local/ld.config -l /usr/local/lib:/lib:/usr/lib -i /usr/local/lib -i /lib -i /usr/lib',
    'Checking that crle command was parsed correctly'
);

is ( $crle->version,
     '4',
     'Checking version parsed from output'
 );

is ( $crle->ld_config,
     '/usr/local/ld.config',
     'Checking path to ld_config parsed from ld.config output'
 );

is( $crle->platform,
    '32-bit LSB 80386',
    'Checking platform string was parsed properly'
);

is( $crle->find_lib( 'libssl.so' ),
    '/usr/local/lib',
    'searching first path for libssl.so'
);

is( $crle->find_lib( 'feklzixlueg.so' ),
    undef,
    'searching for non-existent library'
);

is_deeply( $crle->find_all_libs( 'libssl.so' ),
           [ { '/usr/local/lib'                     => [ 'libssl.so', 'libssl.so.0.9.8' ] },
             { '/usr/local/root/openssl-0.9.8l/lib' => [ 'libssl.so.0.9.8'              ] },
             { '/lib'                               => [ 'libssl.so', 'libssl.so.0.9.8' ] },
         ],
           'searching all paths for regexp libssl.so'
       );
