package Git::ReleaseRepo::Command::init;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Cwd qw( abs_path );
use File::Spec::Functions qw( catdir catfile );
use File::HomeDir;
use File::Path qw( make_path );
use File::Slurp qw( write_file );

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $dir = $opt->{root} || catdir( File::HomeDir->my_home, 'release' );
    my $conf_dir = catdir( $dir, '.release' );
    if ( -e $conf_dir ) {
        die "Cannot initialize: Directory '$conf_dir' already exists!\n";
    }
    make_path( $conf_dir );
    write_file( catfile( $conf_dir, 'config' ), '' );
    if ( $opt->{root} && !$ENV{GIT_RELEASE_ROOT} || $ENV{GIT_RELEASE_ROOT} ne $dir ) {
        print "Add 'GIT_RELEASE_ROOT=$dir' to your environment, or add '--root $dir' to your commands.\n";
    }
};

1;
__END__


