package Git::ReleaseRepo::Command::status;

use strict;
use warnings;
use List::MoreUtils qw( uniq );
use Moose;
extends 'Git::ReleaseRepo::Command';
augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    $self->checkout;
    my $latest_version = $self->latest_version;
    my %outdated = map { $_ => 1 } $self->outdated;
    my %diff = $latest_version ? map { $_ => 1 } $self->outdated( 'refs/tags/' . $latest_version ) 
            # If we haven't had a release yet, everything we have is different
             : map { $_ => 1 } keys %{$self->submodule};

    my $header = "Changes since " . ( $latest_version || "development started" );
    print $header . "\n";
    print "-" x length( $header ) . "\n";
    my @changed = sort( uniq( keys %outdated, keys %diff ) );
    #; use Data::Dumper; print Dumper \@changed;
    for my $changed ( @changed ) {
        print "$changed ";
        if ( !$latest_version || $diff{ $changed } ) {
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


