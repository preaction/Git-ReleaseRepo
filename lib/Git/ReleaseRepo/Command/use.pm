package Git::ReleaseRepo::Command::use;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Cwd qw( abs_path );
use File::Spec::Functions qw( catdir catfile );
use File::HomeDir;
use File::Path qw( make_path );
use File::Slurp qw( write_file );

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    $self->usage_error( "Must give a repository name to use!" ) if ( @$args != 1 );
    die "Could not find release repository '$args->[0]' in directory '@{[$self->repo_root]}'!\n"
        if !-d catdir( $self->repo_root, $args->[0] );
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'version_prefix:s' => 'Set the version prefix of the release repository' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $config = $self->config;
    # Delete old default repo
    for my $repo_name ( keys %$config ) {
        my $repo_conf = $config->{$repo_name};
        delete $repo_conf->{default};
    }
    # Set new default repo and configuration
    my $repo_conf = $config->{$args->[0]} ||= {};
    $repo_conf->{default} = 1;
    for my $conf ( qw( version_prefix ) ) {
        if ( exists $opt->{$conf} ) {
            $repo_conf->{$conf} = $opt->{$conf};
        }
    }
};

1;
__END__


