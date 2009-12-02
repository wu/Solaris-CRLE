package Solaris::CRLE;
use Mouse;

our $VERSION;

#_* Libraries

use Carp;

=head1 NAME

Solaris::CRLE - configure runtime linking environment for Solaris


=head1 SYNOPSIS

    use Solaris::CRLE;

=head1 DESCRIPTION

=cut

#_* Attributes

has 'libs'                 => ( is      => 'rw',
                                isa     => 'HashRef[HashRef[Str]]',
                                default => sub { return {} },
                            );

has 'lib_dirs'             => ( is      => 'rw',
                                isa     => 'ArrayRef[Str]',
                                default => sub { return [] },
                            );

has 'command'              => ( is      => 'rw',
                                isa     => 'Str',
                            );

has 'default_library_path' => ( is      => 'rw',
                                isa     => 'ArrayRef[Str]',
                                default => sub { [ ] },
                            );

has 'trusted_directories'  => ( is      => 'rw',
                                isa     => 'ArrayRef[Str]',
                                default => sub { [] },
                            );

has 'version'              => ( is      => 'rw',
                                isa     => 'Int',
                                default => 0,
                            );

has 'ld_config'            => ( is      => 'rw',
                                isa     => 'Str',
                                default => sub {
                                    my $path = $ENV{LD_CONFIG} || '/var/ld/ld.config';
                                    unless ( -r $path ) { die "ERROR: no ld.config path found" }
                                    return $path;
                                },
                            );

has 'platform'             => ( is      => 'rw',
                                isa     => 'Str',
                                default => "",
                            );

#_* Methods

=head1 SUBROUTINES/METHODS

=over 8

=item parse()

Executes the crle command against the ld.config file and then call
parse_output on the results.

=cut

sub parse {
    my ( $self ) = @_;

    my $command = join " ", '/usr/bin/crle', '-c', $self->ld_config;

    my @lines;

    # run command capturing output
    open my $run, "-|", "$command 2>&1" or die "Unable to run $command: $!";
    while ( my $line = <$run> ) {
        chomp $line;
        push @lines, $line;
    }
    close $run;
    
    # check exit status
    unless ( $? eq 0 ) {
      my $status = $? >> 8;
      my $signal = $? & 127;
      die "Error running command:$command\n\tstatus=$status\n\tsignal=$signal";
    }

    $self->parse_output( @lines );
}

=item parse_output()

Given an array of lines that is the output of the crle command, parse
each line and update internal data structures appropraitely.

=cut

sub parse_output {
    my ( $self, @lines ) = @_;

    # data and ordered lib directories
    my $data;
    my @lib_dirs;

    # keep state while in the loop
    my $current_dir;

  LINE:
    for my $line ( @lines ) {
        chomp $line;
        next unless $line;

        if ( $current_dir && $line =~ m|^  (.*)$| ) {
            $data->{$current_dir}->{$1} = 1;
        }
        elsif ( $line =~ m|^Directory: (.*)\s*$| ) {
            $current_dir = $1;
            $data->{$current_dir} = {};
            push @lib_dirs, $current_dir;
        }
        elsif ( $line =~ m|^Configuration file| ) {
            if ( $line =~ m|version (\d+)| ) {
                $self->version( $1 );
            }
            if ( $line =~ m|\:\s(\S+)| ) {
                $self->ld_config( $1 );
            }
        }
        elsif ( $line =~ m|^\s+Platform| ) {
            if ( $line =~ m|^.*?\:\s*(.*)$| ) {
                $self->platform( $1 );
            }
        }
        elsif ( $line =~ m|^\s+Default Library Path| ) {
            if ( $line =~ m|^.*?\:\s+(.*)$| ) {
                $self->default_library_path( [ split /\:/, $1 ] );
            }
        }
        elsif ( $line =~ m|^\s+Trusted Directories| ) {
            $line =~ s|\s*\(system default\)$||;
            if ( $line =~ m|^.*?\:\s+(.*)$| ) {
                $self->trusted_directories( [ split /\:/, $1 ] );
            }
        }
        elsif ( $line =~ m|^Command line| ) {
            last LINE;
        }
        else {
            print "UNPARSED: $line\n";
        }
    }

    $self->libs(     $data      );
    $self->lib_dirs( \@lib_dirs );

    if ( $lines[-2] ) {
        my $command = $lines[-2];
        chomp $command;
        $command =~ s|^\s+||;
        $self->command( $command );
    }

}

=item $obj->find_lib( $lib )

Search for a single library by name.

The library paths will be searched in order, and the first directory
containing the specified library will be returned.

=cut

sub find_lib {
    my ( $self, $lib ) = @_;

    for my $lib_dir ( @{ $self->lib_dirs } ) {
        if ( $self->libs->{$lib_dir}->{$lib} ) {
            return $lib_dir;
        }
    }

    return;
}

=item $obj->find_all_libs( $match )

Search for all libraries matching the specified pattern.

The library paths will be searched in order, and all matching
libraries in each directory will be returned.

The data returned is an array ref of hashes, where the key of each
hash is a directory, and the value is an array of libraries found in
the directory, sorted alphabetically.  For example:

  [ { 'dir1' => [ 'lib1', 'lib2' ] },
    { 'dir2' => [ 'lib1', 'lib3' ] },
  ]

=cut

sub find_all_libs {
    my ( $self, $regexp ) = @_;

    my @matches;

    for my $lib_dir ( @{ $self->lib_dirs } ) {
        my @dir_matches;
        for my $lib ( sort keys %{ $self->libs->{$lib_dir} } ) {
            if ( $lib =~ m|$regexp|  ) {
                push @dir_matches, $lib;
            }
        }
        next unless @dir_matches;
        push @matches, { $lib_dir => \@dir_matches };
    }

    return \@matches;
}


#_* End


1;

__END__

=back

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, VVu@geekfarm.org
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

- Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
