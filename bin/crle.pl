#!/usr/local/bin/perl -w
use strict;
use warnings;

our $VERSION;

require Algorithm::Diff;
use Getopt::Long;
use Pod::Usage;

use Solaris::CRLE;

my %opt;

unless ( GetOptions ( '-c|config=s' => \$opt{path},
                      '-f|find=s'   => \$opt{find},
                      '-r|regexp=s' => \$opt{regexp},
                      '-t|temp'     => \$opt{temp},
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
    $crle_opts{ld_config} = $opt{path};
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
elsif ( $opt{update} ) {
    print "\nRe-generating ld.config file\n";
    $crle->generate();
    print "\nDone!\n";
}
elsif ( $opt{diff} ) {

    my $command = $crle->command;

    my $file = "/tmp/ld.config.$$";
    if ( -r $file ) { unlink $file }
    if ( -r $file ) { die "ERROR: temporary file collision: unable to remove temp file: $file" }

    if ( $command =~ m| \-c | ) {
        $command =~ s| \-c \S+| -c $file|;
    }
    else {
        $command =~ s|crle |crle -c $file|;
    }

    print "\nCreating temporary ld.config: $command\n\n";
    my $temp_crle = Solaris::CRLE->new( ld_config => $file,
                                        command   => $command,
                                    );
    $temp_crle->generate();
    $temp_crle->parse();

    my @orig_list = $crle->generate_list();
    my @temp_list = $temp_crle->generate_list();

    print "Diffing existing ld.config from temporary ld.config\n\n";
    my $diff = Algorithm::Diff->new( \@orig_list, \@temp_list );

    $diff->Base( 1 );

    my $diff_count = 0;
    while(  $diff->Next()  ) {
        next   if  $diff->Same();

        $diff_count++;

        print "Deleted: $_\n" for  $diff->Items(1);
        print "Added:   $_\n" for  $diff->Items(2);
    }

    unless ( $diff_count ) {
        print "No differences found!\n";
    }
    
    unlink $file;
}
else {
    print "No valid action specified\n";
}
