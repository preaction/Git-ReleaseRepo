package Git::ReleaseRepo::Command::push;
# ABSTRACT: Push a release

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use Git::Repository;

with 'Git::ReleaseRepo::WithVersionPrefix';

sub description {
    return 'Push a release to an origin repository';
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $version = $args->[0] || $self->git->current_branch;
    for my $git ( $self->git, map { $self->git->submodule_git( $_ ) } keys $self->git->submodule ) {
        my $cmd = $git->command( 'push', 'origin', "$version:$version" );
        my @stderr = readline $cmd->stderr;
        my @stdout = readline $cmd->stdout;
        $cmd->close;
        if ( $cmd->exit != 0 ) {
            die "ERROR: Could not push.\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                . "\nSTDOUT: " . ( join "\n", @stdout );
        }
        $cmd = $git->command( 'push', 'origin', '--tags' );
        @stderr = readline $cmd->stderr;
        @stdout = readline $cmd->stdout;
        $cmd->close;
        if ( $cmd->exit != 0 ) {
            die "ERROR: Could not push tags.\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                . "\nSTDOUT: " . ( join "\n", @stdout );
        }
    }
    return 0;
};

1;
__END__
