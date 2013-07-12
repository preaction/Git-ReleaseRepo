package Git::ReleaseRepo::Command::checkout;
# ABSTRACT: Checkout a release repository to work on it

use Moose;
extends 'Git::ReleaseRepo::Command';
with 'Git::ReleaseRepo::WithVersionPrefix';

override usage_desc => sub {
    my ( $self ) = @_;
    return super();
};

sub description {
    return 'Checkout a release repository to work on it';
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( $opt->{bugfix} && @$args ) {
        return $self->usage_error( "--bugfix does not allow arguments" );
    }
    return $self->usage_error( "checkout requires an argument" ) if ( !$opt->{bugfix} && @$args == 0 );
    return $self->usage_error( "Too many arguments" ) if ( @$args > 1 );
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'bugfix' => 'Checkout the most-recent release branch' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $repo = $self->git;
    if ( $opt->bugfix ) {
        my $rel_branch = $repo->latest_release_branch;
        $repo->checkout( $rel_branch );
    }
    else {
        $repo->checkout( $args->[0] );
    }
};

1;
__END__

