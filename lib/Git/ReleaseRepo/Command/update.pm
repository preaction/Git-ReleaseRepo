package Git::ReleaseRepo::Command::update;
# ABSTRACT: Update an existing module in the next release

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use File::Spec::Functions qw( catdir );

with 'Git::ReleaseRepo::WithVersionPrefix';

override usage_desc => sub {
    my ( $self ) = @_;
    return super() . " <module_name> [<module_name>...]";
};

sub description {
    return 'Update an existing module in the next release';
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig(),
        [ 'all|a' => "Update all out-of-date modules in the release" ],
    );
};

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( $opt->all ) { 
        if ( @$args ) {
            return $self->usage_error( "--all does not make sense with module names to update" );
        }
    }
    else {
        if ( scalar @$args < 1 ) {
            return $self->usage_error( "You must specify a submodule to update in the next release" );
        }
    }
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $git = $self->git;
    my $branch = $git->current_branch;
    if ( $opt->all ) {
        $args = [$git->outdated_branch];
    }
    for my $mod ( @$args ) {
        $self->update_submodule( $mod, $branch );
    }
    my $message = @$args == 1
                ? "Updating $args->[0]"
                : "Updating all outdated:\n"
                    . join "\n", map { sprintf "\t\%s", $_ } sort @$args;
    $git->run( commit => ( @$args ), -m => $message );
};

sub update_submodule {
    my ( $self, $module, $branch ) = @_;
    $branch ||= "master";
    my $git = $self->git;
    if ( !$git->submodule->{ $module } ) {
        die "Cannot add $module: Submodule does not exist\n";
    }
    my $subgit = $git->submodule_git( $module );
    my $cmd = $subgit->command( 'fetch' );
    $cmd->close;
    $cmd = $subgit->command( checkout => $branch );
    my @stdout = readline $cmd->stdout;
    my @stderr = readline $cmd->stderr;
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "Could not checkout '$branch': \nSTDERR: " . ( join "\n", @stderr )
            . "\nSTDOUT: " . ( join "\n", @stdout );
    }
    $cmd = $subgit->command( pull => 'origin', $branch );
    @stdout = readline $cmd->stdout;
    @stderr = readline $cmd->stderr;
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "Could not pull 'origin' '$branch': \nSTDERR: " . ( join "\n", @stderr )
            . "\nSTDOUT: " . ( join "\n", @stdout );
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Git::ReleaseRepo::Command::update - Update an existing module in the next release

=head1 DESCRIPTION


