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
    my $branch;
    if ( $opt->bugfix ) {
        $branch = $repo->latest_release_branch;
    }
    else {
        $branch = $args->[0];
    }
    $repo->checkout( $branch );
    if ( $repo->has_remote( 'origin' ) ) {
        # Check if the repo needs updating
        $repo->run( 'fetch', 'origin' );
        my %ref = $repo->show_ref;
        ; use Data::Dumper; print Dumper \%ref;
        my $ref_spec = 'refs/remotes/origin/' . $branch;
        if ( $ref{HEAD} ne $ref{$ref_spec} ) {
            my ( $code, $stdout, $stderr ) = $repo->run_cmd( 'branch', '--contains', $ref{$ref_spec} );
            print $stdout;
            my @branches = map { s/^\*\s+//; $_ } split /\n/, $stdout;
            print join "\n", @branches;
            if ( !grep { $_ eq $branch } @branches ) {
                # If we don't, we can pull
                print "Your branch is out of date. Use `git release update` to update.\n";
            }
        }
    }
};

1;
__END__

