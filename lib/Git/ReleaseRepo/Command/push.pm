package Git::ReleaseRepo::Command::push;
# ABSTRACT: Push a release

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use Git::Repository;
use Progress::Any;

with 'Git::ReleaseRepo::WithVersionPrefix';

sub description {
    return 'Push a release to an origin repository';
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my @versions = $args->[0] ? ( $args->[0] )
                 : $self->git->current_branch ne 'master' ? ( $self->git->current_branch )
                 : ( 'master', $self->git->latest_release_branch )
                 ;
    my $version_prog = Progress::Any->get_indicator( task => 'main' );
    $version_prog->pos( 0 );
    $version_prog->target( ~~@versions );
    for my $version ( @versions ) {
        my @repos = ( $self->git, map { $self->git->submodule_git( $_ ) } keys %{ $self->git->submodule } );
        my $repo_prog = Progress::Any->get_indicator( task => "main.push" );
        $repo_prog->pos( 0 );
        $repo_prog->target( ~~@repos );
        for my $git ( @repos ) {
            my ( $name ) = $git->work_tree =~ m{/([^/]+)$};
            unless ( $git->has_remote( 'origin' ) ) {
                # This submodule, for some reason, only exists inside this repository
                $repo_prog->update( message => "Skipped $name" );
                next;
            }
            unless ( $git->has_branch( $version ) ) {
                # Can't push a refspec that doesn't exist
                $repo_prog->update( message => "Fetching $name" );
                my $cmd = $git->command( 'fetch', 'origin' );
                my @stderr = readline $cmd->stderr;
                my @stdout = readline $cmd->stdout;
                $cmd->close;
                if ( $cmd->exit != 0 ) {
                    die "ERROR: Could not fetch.\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                        . "\nSTDOUT: " . ( join "\n", @stdout );
                }
                $cmd = $git->command( checkout => $version );
                @stderr = readline $cmd->stderr;
                @stdout = readline $cmd->stdout;
                $cmd->close;
                if ( $cmd->exit != 0 ) {
                    die "Could not checkout branch $version\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                        . "\nSTDOUT: " . ( join "\n", @stdout );
                }
            }
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
            $repo_prog->update( message => "Pushed $name" );
        }
        $repo_prog->finish;
        $version_prog->update( message => "Pushed $version" );
    }
    $version_prog->finish;
    return 0;
};

1;
__END__
