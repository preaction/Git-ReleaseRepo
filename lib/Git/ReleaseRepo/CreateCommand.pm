package Git::ReleaseRepo::CreateCommand;
# ABSTRACT: Base class for commands that have to create a new repository

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use File::Spec::Functions qw( catfile );
use YAML qw( LoadFile DumpFile );

sub update_config {
    my ( $self, $opt, $repo, $extra ) = @_;
    my $config_file = catfile( $repo->git_dir, 'release' );
    my $config = -f $config_file ? LoadFile( $config_file ) : {};

    for my $conf ( qw( version_prefix ) ) {
        if ( exists $opt->{$conf} ) {
            $config->{$conf} = $opt->{$conf};
        }
    }

    $config = { %$config, %$extra };
    DumpFile( $config_file, $config );
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    $self->usage_error( "Must give a repository URL!" ) if ( @$args < 1 );
    $self->usage_error( "Too many arguments" ) if ( @$args > 2 );
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'version_prefix:s' => 'Set the version prefix of the release repository' ],
    );
};

1;
