package Git::ReleaseRepo::Command;

use strict;
use warnings;
use Moose;
use App::Cmd::Setup -command;
use YAML::Tiny;
use File::HomeDir;
use File::Spec::Functions qw( catfile );
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

sub execute {
    my ( $self, $opt, $args ) = @_;
    inner();
    $self->write_config;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
