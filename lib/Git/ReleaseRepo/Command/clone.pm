package Git::ReleaseRepo::Command::clone;
# ABSTRACT: Clone an existing release repository

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use Cwd qw( abs_path );
use File::Spec::Functions qw( catdir catfile );
use File::HomeDir;
use File::Path qw( make_path );
use File::Slurp qw( write_file );
use File::Basename qw( basename );

sub repo_name_from_url {
    my ( $self, $repo_url ) = @_;
    my ( $repo_name ) = $repo_url =~ m{/([^/]+)$};
    $repo_name =~ s/[.]git$//;
    return $repo_name;
}

override usage_desc => sub {
    my ( $self ) = @_;
    return super() . " <repo_url> [<repo_name>]";
};

sub description {
    return 'Clone an existing release repository';
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    $self->usage_error( "Must give a repository URL!" ) if ( @$args < 1 );
    $self->usage_error( "Too many arguments" ) if ( @$args > 2 );
    my $repo_name = $args->[1] || $self->repo_name_from_url( $args->[0] );
    die "Release repository name '$args->[1]' already exists in '@{[$self->repo_root]}'!\n"
        if -d catdir( $self->repo_root, $repo_name );
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'version_prefix:s' => 'Set the version prefix of the release repository' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    # Clone the repo
    my $repo_name = $args->[1] || $self->repo_name_from_url( $args->[0] );
    my $repo_dir  = catdir( $self->repo_root, $repo_name );
    my $cmd = Git::Repository->command( clone => $args->[0], $repo_dir );
    my @stdout = readline $cmd->stdout;
    my @stderr = readline $cmd->stderr;
    $cmd->close;
    print @stdout if @stdout;
    print @stderr if @stderr;

    my $config = $self->config;
    # Delete old default repo
    for my $repo_name ( keys %$config ) {
        my $repo_conf = $config->{$repo_name};
        delete $repo_conf->{default};
    }

    # Set new default repo and configuration
    my $repo_conf = $config->{$repo_name} ||= {};
    $repo_conf->{default} = 1;
    for my $conf ( qw( version_prefix ) ) {
        if ( exists $opt->{$conf} ) {
            $repo_conf->{$conf} = $opt->{$conf};
        }
    }
};

1;
__END__


