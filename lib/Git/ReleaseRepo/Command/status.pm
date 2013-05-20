package Git::ReleaseRepo::Command::status;

use strict;
use warnings;
use List::MoreUtils qw( uniq );
use Moose;
extends 'Git::ReleaseRepo::Command';

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig(),
        [ 'bugfix' => 'Check the status of the current release branch' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    # "master" looks at master since latest release branch
    # "bugfix" looks at release branch since latest release
    my ( $since_version, %outdated, %diff );
    if ( $opt->bugfix ) {
        my $rel_branch = $self->latest_release_branch;
        $self->checkout( $rel_branch );
        $since_version = $self->latest_version( $rel_branch );
        %outdated = map { $_ => 1 } $self->outdated( 'refs/heads/' . $rel_branch );
        %diff = map { $_ => 1 } $self->outdated( 'refs/tags/' . $since_version );
    }
    else {
        $self->checkout;
        $since_version = $self->latest_release_branch;
        %outdated = map { $_ => 1 } $self->outdated( 'refs/heads/master' );
        %diff = $since_version ? map { $_ => 1 } $self->outdated( 'refs/tags/' . $since_version . '.0' ) 
                # If we haven't had a release yet, everything we have is different
                 : map { $_ => 1 } keys %{$self->submodule};
    }

    my $header = "Changes since " . ( $since_version || "development started" );
    print $header . "\n";
    print "-" x length( $header ) . "\n";
    my @changed = sort( uniq( keys %outdated, keys %diff ) );
    #; use Data::Dumper; print Dumper \@changed;
    for my $changed ( @changed ) {
        print "$changed";
        if ( !$since_version || $diff{ $changed } ) {
            print " changed";
        }
        if ( $outdated{$changed} ) {
            print " (can add)";
        }
        print "\n";
    }
    $self->checkout;
};

1;
__END__


