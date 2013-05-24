package Git::ReleaseRepo::Command::config;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Cwd qw( abs_path );

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $cmd = shift @$args;
    if ( $cmd eq 'add' ) {
        $self->config->{ $args->[0] }{ work_tree } = abs_path( $args->[1] );
    }
};

1;
__END__


