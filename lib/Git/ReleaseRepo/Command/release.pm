package Git::ReleaseRepo::Command::release;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Git::Repository;

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( @$args != 1 ) {
        return $self->usage_error( "Must specify version to release" );
    }
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $version = $args->[0];
    $self->checkout;
    # Branch all modules too!
    for my $module ( keys $self->submodule ) {
        my $subgit = $self->submodule_git( $module );
        $subgit->run( branch => $version );
        $subgit->run( push => origin => "$version:$version" );
    }
    $self->git->run( branch => $version );
    $self->git->run( push => origin => "$version:$version" );
};

1;
__END__
