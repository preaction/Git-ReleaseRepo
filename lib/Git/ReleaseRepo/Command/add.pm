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
        [ 'bugfix' => 'Add to the latest release branch as a bug fix' ],
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
    my $branch;
    if ( $opt->bugfix ) {
        $branch = $self->latest_release_branch;
        die "Cannot add with --bugfix: No release branch found!\n" if !$branch;
    }
    else {
        $branch = "master";
    }
    if ( $self->has_branch( $self->git, $branch ) ) {
        $self->checkout( $branch );
    }
    if ( $opt->all ) {
        my @outdated = $self->outdated;
        for my $outdated ( @outdated ) {
            $self->update_submodule( $outdated, $branch );
        }
        my $message = "Updating all outdated:\n"
                    . join "\n", map { sprintf "\t\%s", $_ } sort @outdated;
        $self->git->run( commit => ( @outdated ), -m => $message );
    }
    elsif ( @$args == 1 ) {
        $self->update_submodule( @$args, $branch );
        $self->git->run( commit => ( @$args ), -m => "Updating $args->[0]" );
    }
    elsif ( @$args == 2 ) {
        $self->add_submodule( @$args );
        $self->git->run( commit => ( '.gitmodules', $args->[0] ), -m => "Adding $args->[0] to release" );
    }
    $self->checkout;
};

sub update_submodule {
    my ( $self, $module, $branch ) = @_;
    $branch ||= "master";
    if ( !$self->submodule->{ $module } ) {
        die "Cannot add $module: Submodule does not exist\n";
    }
    my $subgit = Git::Repository->new(
        work_tree => catdir( $self->git->work_tree, $module ),
    );
    my $cmd = $subgit->command( 'fetch' );
    $cmd->close;
    $cmd = $subgit->command( checkout => 'origin/' . $branch );
    my @stdout = readline $cmd->stdout;
    my @stderr = readline $cmd->stderr;
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "Could not checkout 'origin/$branch': \nSTDERR: " . ( join "\n", @stderr )
            . "\nSTDOUT: " . ( join "\n", @stdout );
    }
}

sub add_submodule {
    my ( $self, $module, $repo ) = @_;
    my $git = $self->git;
    $git->run(
        submodule => add => '--', $repo, $module,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

