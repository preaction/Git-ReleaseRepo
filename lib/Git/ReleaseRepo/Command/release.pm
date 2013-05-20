package Git::ReleaseRepo::Command::release;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Git::Repository;

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig(),
        [ 'bugfix' => 'Release a bugfix release from the release branch' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my ( $version, $branch_version );
    my $prefix = $self->release_prefix;
    if ( $args->[0] ) {
        $version = $args->[0];
        ( $branch_version ) = $args->[0] =~ m/^($prefix\d+[.]\d+)/;
    }
    else {
        my $latest_version = $self->latest_version;
        my @parts = $latest_version ? split /[.]/, $latest_version
                  : ( "${prefix}0", 0, 0 ); # Our first release!
        if ( $opt->{bugfix} ) {
            # Bugfix releases increment the third number
            $parts[2]++;
        }
        else {
            # Normal releases increment the second number
            $parts[1]++;
            $parts[2] = 0;
        }
        # Remove anything after the 3rd number. If they wanted more, they
        # should have given us an argument!
        $version = join ".", @parts[0..2];
        $branch_version = join ".", @parts[0..1];
    }
    print "Release version $version\n";
    print "Starting release cycle $branch_version\n" if !$opt->{bugfix};
    if ( $opt->bugfix ) {
        $self->checkout( $self->latest_release_branch );
    }
    else {
        $self->checkout;
    }
    # Release all modules too!
    for my $module ( keys $self->submodule ) {
        my $subgit = $self->submodule_git( $module );
        if ( !$opt->{bugfix} ) {
            $self->branch_release( $subgit, $branch_version );
        }
        $self->tag_release( $subgit, $version );
    }
    if ( !$opt->{bugfix} ) {
        $self->branch_release( $self->git, $branch_version );
    }
    $self->tag_release( $self->git, $version );
};

sub branch_release {
    my ( $self, $git, $version ) = @_;
    $git->run( branch => $version );
    if ( $self->has_remote( $git, 'origin' ) ) {
        $git->command( push => origin => "$version:$version" );
    }
}

sub tag_release {
    my ( $self, $git, $version ) = @_;
    $git->run( tag => $version );
    if ( $self->has_remote( $git, 'origin' ) ) {
        $git->command( push => origin => '--tags' );
    }
}

1;
__END__
