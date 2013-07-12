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
    # TODO: Recurse manually for better diagnostics
    my $cmd = $self->git->command( 'push', '--recurse-submodules=on-demand' );
    my @stderr = readline $cmd->stderr;
    my @stdout = readline $cmd->stdout;
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "ERROR: Could not push.\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
            . "\nSTDOUT: " . ( join "\n", @stdout );
    }
    return 0;
};

1;
__END__
