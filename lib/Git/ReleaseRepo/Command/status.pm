package Git::ReleaseRepo::Command::status;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';
use Git::Repository;
use feature qw( say );
use File::Spec::Functions qw( catdir );

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $git = $self->git;
    my %submod_refs = $self->submodule;
    my @outdated;

    for my $submod ( keys %submod_refs ) {
        my $subgit = Git::Repository->new(
                        work_tree => catdir( $self->git->work_tree, $submod ),
                    );
        my %remote = $self->ls_remote( $subgit );
        if ( $submod_refs{ $submod } ne $remote{'refs/heads/master'} ) {
            push @outdated, $submod;
        }
    }

    print map { sprintf "\%s is out of date\n", $_ } sort @outdated;
};

sub ls_remote {
    my ( $self, $git ) = @_;
    my %refs;
    my $cmd = $git->command( 'ls-remote', 'origin' );
    while ( defined( my $line = readline $cmd->stdout ) ) {
        # <SHA1 hash> <symbolic ref>
        my ( $ref_id, $ref_name ) = split /\s+/, $line;
        $refs{ $ref_name } = $ref_id;
    }
    return wantarray ? %refs : \%refs;
}

1;
__END__


