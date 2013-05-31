package Git::ReleaseRepo::Command;

use strict;
use warnings;
use Moose;
use App::Cmd::Setup -command;
use YAML qw( LoadFile DumpFile );
use List::Util qw( first );
use File::HomeDir;
use File::Spec::Functions qw( catfile catdir );
use Git::Repository qw( +Git::ReleaseRepo::Repository );

has config_file => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        catfile( $_[0]->repo_root, '.release', 'config' );
    },
);

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my ( $self ) = @_;
        if ( -f $self->config_file ) {
            return LoadFile( $self->config_file ) || {};
        }
        else {
            return {};
        }
    },
);

sub write_config {
    my ( $self ) = @_;
    return DumpFile( $self->config_file, $self->config );
}

has repo_name => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ( $self ) = @_;
        my $config = $self->config;
        return first { $config->{$_}{default} } keys %$config;
    },
);

has repo_dir => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { catdir( $_[0]->repo_root, $_[0]->repo_name ) },
);

has git => (
    is      => 'ro',
    isa     => 'Git::Repository',
    lazy    => 1,
    default => sub {
        my $repo_dir = $_[0]->repo_dir;
        my $git = Git::Repository->new(
            work_tree => $_[0]->repo_dir,
            git_dir => catdir( $_[0]->repo_dir, '.git' ),
        );
        $git->release_prefix( $_[0]->release_prefix );
        return $git;
    },
);

has release_prefix => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        return $_[0]->config->{$_[0]->repo_name}{version_prefix};
    },
);

has repo_root => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        return $ENV{GIT_RELEASE_ROOT} || catdir( File::HomeDir->my_home, 'release' );
    },
);

sub repo_name_from_url {
    my ( $self, $repo_url ) = @_;
    my ( $repo_name ) = $repo_url =~ m{/([^/]+)$};
    $repo_name =~ s/[.]git$//;
    return $repo_name;
}

sub opt_spec {
    return (
        [ 'repo_dir=s' => 'The path to the release repository' ],
        [ 'prefix=s' => 'The release version prefix, like "v" or "ops-"' ],
        [ 'root=s' => 'The root directory for release repositories' ],
        [ 'repo=s' => 'The name of the repo to use. Defaults to the repo selected by "use"' ],
    );
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    if ( exists $opt->{repo} ) {
        $self->repo_name( $opt->{repo} );
    }
    if ( exists $opt->{root} ) {
        $self->repo_root( $opt->{root} );
    }
    if ( exists $opt->{repo_dir} ) {
        $self->repo_dir( $opt->{repo_dir} );
    }
    if ( exists $opt->{prefix} ) {
        $self->release_prefix( $opt->{prefix} );
    }

    inner();

    $self->write_config;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
