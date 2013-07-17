package Git::ReleaseRepo::CreateCommand;
# ABSTRACT: Base class for commands that have to create a new repository

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use File::Spec::Functions qw( catfile );
use YAML qw( LoadFile DumpFile );

override usage_desc => sub {
    my ( $self ) = @_;
    return super() . " <repo_url> [<repo_name>]";
};

sub update_config {
    my ( $self, $opt, $repo, $extra ) = @_;
    $extra ||= {};
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
    return $self->usage_error( "Must give a repository URL!" ) if ( @$args < 1 );
    return $self->usage_error( "Too many arguments" ) if ( @$args > 2 );
    return $self->usage_error( 'Must specify --version_prefix' ) unless $opt->{version_prefix};
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'version_prefix:s' => 'Set the version prefix of the release repository' ],
    );
};

1;
