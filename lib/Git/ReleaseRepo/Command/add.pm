package Git::ReleaseRepo::Command::add;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use File::Spec::Functions qw( catdir );
use Git::Repository;

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig(),
        [ 'all|a' => "Add all out-of-date modules to the release" ],
    );
};

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( $opt->all ) { 
        if ( @$args ) {
            return $self->usage_error( "--all does not make sense with module names to add" );
        }
    }
    else {
        if ( scalar @$args < 1 ) {
            return $self->usage_error( "You must specify a submodule to add to the next release" );
        }
        if ( scalar @$args > 2 ) {
            return $self->usage_error( "Too many arguments" );
        }
    }
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    if ( $opt->all ) {
        my @outdated = $self->outdated;
        for my $outdated ( @outdated ) {
            $self->update_submodule( $outdated );
        }
        my $message = "Updating all outdated:\n"
                    . join "\n", map { sprintf "\t\%s", $_ } sort @outdated;
        $self->git->run( commit => ( '.gitmodules', @outdated ), -m => $message );
    }
    elsif ( @$args == 1 ) {
        $self->update_submodule( @$args );
        $self->git->run( commit => ( '.gitmodules', $args->[0] ), -m => "Updating $args->[0]" );
    }
    elsif ( @$args == 2 ) {
        $self->add_submodule( @$args );
        $self->git->run( commit => ( '.gitmodules', $args->[0] ), -m => "Adding $args->[0] to release" );
    }
};

sub update_submodule {
    my ( $self, $module ) = @_;
    if ( !$self->submodule->{ $module } ) {
        die "Cannot add $module: Submodule does not exist\n";
    }
    my $subgit = Git::Repository->new(
        work_tree => catdir( $self->git->work_tree, $module ),
    );
    $subgit->run( 'fetch' );
    $subgit->run( checkout => 'origin/master' );
}

sub add_submodule {
    my ( $self, $module, $repo ) = @_;
    my $git = $self->git;
    $git->run(
        submodule => add => '--', $repo, $module,
    );
    $git->run( commit => $module, -m => "Adding $module to release" );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

