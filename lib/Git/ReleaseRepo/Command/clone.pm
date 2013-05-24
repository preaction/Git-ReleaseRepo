package Git::ReleaseRepo::Command::clone;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Git::Repository;
use YAML::Tiny;
use File::Basename qw( basename );

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( scalar @$args < 1 ) {
        return $self->usage_error( "You must specify a release repository to clone" );
    }
    if ( scalar @$args > 2 ) {
        return $self->usage_error( "Too many arguments" );
    }
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $output = Git::Repository->run( clone => @$args );
    my ( $directory ) = $output =~ m/Cloning into '([^']+)'/;
    my $name = basename( $directory );
    $self->config->{ $name } = {
        work_tree => $directory,
    };
};

1;
__END__


