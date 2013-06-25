package Git::ReleaseRepo::Command::init;
# ABSTRACT: Initialize Git::ReleaseRepo

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use Cwd qw( getcwd abs_path );
use File::Spec::Functions qw( catdir catfile );
use File::HomeDir;
use File::Path qw( make_path );
use YAML qw( DumpFile );

sub description {
    return 'Initialize Git::ReleaseRepo';
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
    my $dir = $self->git->git_dir;
    my $conf_file = catfile( $dir, 'release' );
    if ( -e $conf_file ) {
        die "Cannot initialize: File '$conf_file' already exists!\n";
    }
    my $repo_conf = {};
    for my $conf ( qw( version_prefix ) ) {
        if ( exists $opt->{$conf} ) {
            $repo_conf->{$conf} = $opt->{$conf};
        }
    }
    DumpFile( $conf_file, $repo_conf );
};

1;
__END__


