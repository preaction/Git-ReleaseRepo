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

    for my $submod ( keys %submod_refs ) {
        my $subgit = Git::Repository->new(
                        work_tree => catdir( $self->git->work_tree, $submod ),
                    );
        my %remote = $self->ls_remote( $subgit );
        if ( $submod_refs{ $submod } ne $remote{'refs/heads/master'} ) {
            say "$submod out of date";
        }
    }
};

sub ls_remote {
    my ( $self, $git ) = @_;
    my %refs;
    my @lines = $git->run( 'ls-remote', 'origin' );
    for my $line ( @lines ) {
        # <SHA1 hash> <symbolic ref>
        my ( $ref_id, $ref_name ) = split /\s+/, $line;
        $refs{ $ref_name } = $ref_id;
    }
    return wantarray ? %refs : \%refs;
}

1;
__END__


