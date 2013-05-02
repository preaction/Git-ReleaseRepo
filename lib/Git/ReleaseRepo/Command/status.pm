package Git::ReleaseRepo::Command::status;

use strict;
use warnings;
use List::MoreUtils qw( uniq );
use Moose;
extends 'Git::ReleaseRepo::Command';
augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $latest_version = $self->latest_version;
    my %outdated = map { $_ => 1 } $self->outdated;
    my %diff = map { $_ => 1 } $self->outdated( 'refs/heads/' . $latest_version );

    my $header = "Changes since " . $latest_version;
    print $header . "\n";
    print "-" x length( $header ) . "\n";
    my @changed = sort( uniq( keys %outdated, keys %diff ) );
    #; use Data::Dumper; print Dumper \@changed;
    for my $changed ( @changed ) {
        print "$changed ";
        if ( $diff{ $changed } ) {
            print "changed";
        }
        if ( $outdated{$changed} ) {
            print " (can add)";
        }
        print "\n";
    }
};

1;
__END__


