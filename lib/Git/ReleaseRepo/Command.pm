package Git::ReleaseRepo::Command;

use strict;
use warnings;
use Moose;
use App::Cmd::Setup -command;
use YAML::Tiny;
use File::HomeDir;
use File::Spec::Functions qw( catfile catdir );
use Git::Repository;

has config_file => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        catfile( File::HomeDir->my_home, '.releaserepo' );
    },
);

has config => (
    is      => 'ro',
    isa     => 'YAML::Tiny',
    lazy    => 1,
    default => sub {
        my ( $self ) = @_;
        if ( -f $self->config_file ) {
            return YAML::Tiny->read( $self->config_file );
        }
        else {
            return YAML::Tiny->new;
        }
    },
);

sub write_config {
    my ( $self ) = @_;
    return $self->config->write( $self->config_file );
}

has git => (
    is      => 'ro',
    isa     => 'Git::Repository',
    lazy    => 1,
    default => sub {
        my ( $self ) = @_;
        my $repo = $self->config->[0];
        my $repo_name = [keys %$repo]->[0];
        return Git::Repository->new(
            work_tree => $repo->{$repo_name}{work_tree},
        );
    },
);

sub submodule {
    my ( $self ) = @_;
    my %submodules;
    for my $line ( $self->git->run( 'submodule' ) ) {
        # <status><SHA1 hash> <submodule> (ref name)
        $line =~ m{^.(\S+)\s(\S+)};
        $submodules{ $2 } = $1;
    }
    return wantarray ? %submodules : \%submodules;
}

sub outdated {
    my ( $self ) = @_;
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
    return @outdated;
}

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

sub execute {
    my ( $self, $opt, $args ) = @_;
    inner();
    $self->write_config;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
