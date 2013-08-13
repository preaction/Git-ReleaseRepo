package Git::ReleaseRepo::Command::clone;
# ABSTRACT: Clone an existing release repository

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::CreateCommand';
use Cwd qw( abs_path getcwd );
use File::Spec::Functions qw( catdir catfile );
use File::HomeDir;
use File::Path qw( make_path );
use File::Slurp qw( write_file );
use File::Basename qw( basename );

sub description {
    return 'Clone an existing release repository';
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    # Clone the repo
    my $repo_dir = $args->[1];
    if ( !$repo_dir ) {
        $repo_dir = catdir( getcwd, $self->repo_name_from_url( $args->[0] ) );
    }
    my $cmd = Git::Repository->command( clone => $args->[0], $repo_dir );
    my @stdout = readline $cmd->stdout;
    my @stderr = readline $cmd->stderr;
    $cmd->close;
    print @stderr if @stderr;

    my $repo = Git::Repository->new( work_tree => $repo_dir );
    $cmd = $repo->command( submodule => update => '--init' );
    @stdout = readline $cmd->stdout;
    @stderr = readline $cmd->stderr;
    $cmd->close;
    print @stderr if @stderr;

    $self->update_config( $opt, $repo );
};

1;
__END__


