#!/usr/local/bin/perl -w
use strict;
use warnings;

our $VERSION;

use Getopt::Long;
use Pod::Usage;

use Solaris::CRLE;

my %opt;

unless ( GetOptions ( '-c'          => \$opt{path},
                      '-f|find=s'   => \$opt{find},
                      '-r|regexp=s' => \$opt{regexp},
                      '-u|update'   => \$opt{update},
                      '-s|status'   => \$opt{status},
                      '-d|diff'     => \$opt{diff},
                      '-v|verbose!' => \$opt{verbose},
                      '-help|?'		=> \$opt{help},
    )
) { pod2usage( -exitval => 1, -verbose => 0 ) }

if ( $opt{help} ) {
    pod2usage( -exitval => 0, -verbose => 1 );
}

my %crle_opts;
if ( $opt{path} ) {
    $crle_opts{path} = $opt{path};
}

my $crle = Solaris::CRLE->new( %crle_opts );

$crle->parse();


if ( $opt{find} ) {
    print $crle->find_lib( $opt{find} );
}
elsif ( $opt{regexp} ) {
    my $libs = $crle->find_all_libs( $opt{regexp} );
    if ( $libs ) {
        for my $dir_a ( @{ $libs } ) {
            for my $dir ( keys %{ $dir_a } ) {
                print "\n$dir\n";
                for my $lib ( @{ $dir_a->{$dir} } ) {
                    print "\t$lib\n";
                }
            }
        }
    }
}
