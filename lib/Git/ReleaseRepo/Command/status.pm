package Git::ReleaseRepo::Command::status;
# ABSTRACT: Show the status of a release repository

use strict;
use warnings;
use List::MoreUtils qw( uniq );
use Moose;
use Git::ReleaseRepo -command;

with 'Git::ReleaseRepo::WithVersionPrefix';

sub description {
    return 'Show the status of a release repository';
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    # "master" looks at master since latest release branch
    # "bugfix" looks at release branch since latest release
    my ( $since_version, %outdated, %diff );
    my $git = $self->git;
    my $bugfix = $git->current_branch ne 'master';
    # Deploy branch
    if ( my $track = $self->config->{track} ) {
        my $current = $git->current_release;
        print "On release $current";
        my $latest = $git->latest_version( $track );
        if ( $git->current_release ne $latest ) {
            print " (can update to $latest)";
        }
        print "\n";
    }
    # Bugfix release
    elsif ( $bugfix ) {
        my $rel_branch = $git->current_branch;
        $since_version = $git->latest_version( $rel_branch );
        %outdated = map { $_ => 1 } $git->outdated( 'refs/heads/' . $rel_branch );
        %diff = map { $_ => 1 } $git->outdated( 'refs/tags/' . $since_version );
    }
    # Regular release
    else {
        $since_version = $git->latest_release_branch;
        %outdated = map { $_ => 1 } $git->outdated( 'refs/heads/master' );
        %diff = $since_version ? map { $_ => 1 } $git->outdated( 'refs/tags/' . $since_version . '.0' ) 
                # If we haven't had a release yet, everything we have is different
                 : map { $_ => 1 } keys %{$git->submodule};
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
};

1;
__END__


