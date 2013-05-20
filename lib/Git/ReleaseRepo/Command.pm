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

has repo_name => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { (keys %{$_[0]->config})[0] },
);

has repo_dir => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->config->{$_[0]->repo_name}{work_tree} },
);

has git => (
    is      => 'ro',
    isa     => 'Git::Repository',
    lazy    => 1,
    default => sub {
        my $repo_dir = $_[0]->repo_dir;
        return Git::Repository->new(
            work_tree => $_[0]->repo_dir,
            git_dir => catdir( $_[0]->repo_dir, '.git' ),
        );
    },
);

has release_prefix => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ( $self ) = @_;
        my $repo = $self->config->[0];
        my $repo_name = [keys %$repo]->[0];
        return $repo->{$repo_name}{release_prefix};
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

sub submodule_git {
    my ( $self, $module ) = @_;
    return Git::Repository->new(
        work_tree => catdir( $self->git->work_tree, $module ),
    );
}

sub outdated {
    my ( $self, $ref ) = @_;
    $ref ||= "refs/heads/master";
    my $git = $self->git;
    my %submod_refs = $self->submodule;
    my @outdated;
    for my $submod ( keys %submod_refs ) {
        my $subgit = $self->submodule_git( $submod );
        my %remote = $self->ls_remote( $subgit );
        if ( !exists $remote{ $ref } || $submod_refs{ $submod } ne $remote{$ref} ) {
            #print "OUTDATED $submod: $submod_refs{$submod} ne $remote{$ref}\n";
            push @outdated, $submod;
        }
    }
    return @outdated;
}

sub checkout {
    my ( $self, $commit ) = @_;
    $commit //= "master";
    my $cmd = $self->git->command( checkout => $commit );
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "Could not checkout '$commit'.\nEXIT: " . $cmd->exit . "\nSTDERR: " . readline $cmd->stderr;
    }
    $cmd = $self->git->command( submodule => update => '--init' );
    my @stderr = readline $cmd->stderr;
    my @stdout = readline $cmd->stdout;
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        die "Could not update submodules to '$commit'.\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
            . "\nSTDOUT: " . ( join "\n", @stdout );
    }
}

sub list_version_refs {
    my ( $self, $match, $rel_branch ) = @_;
    my $prefix = $rel_branch // $self->release_prefix;
    my %refs = $self->show_ref( $self->git );
    my @versions = reverse sort version_sort grep { m{^$prefix} } map { (split "/", $_)[-1] } grep { m{^refs/$match/} } keys %refs;
    return @versions;
}

sub list_versions {
    my ( $self, $rel_branch ) = @_;
    return $self->list_version_refs( 'tags', $rel_branch );
}

sub latest_version {
    my ( $self, $rel_branch ) = @_;
    my @versions = $self->list_versions( $rel_branch );
    return $versions[0];
}

sub list_release_branches {
    my ( $self ) = @_;
    return $self->list_version_refs( 'heads' );
}

sub latest_release_branch {
    my ( $self ) = @_;
    my @branches = $self->list_release_branches;
    return $branches[0];
}

sub version_sort {
    # Assume Semantic Versioning style, plus prefix
    # %s.%i.%i%s
    my @a = $a =~ /^\D*(\d+)[.](\d+)[.](\d+)/;
    my @b = $b =~ /^\D*(\d+)[.](\d+)[.](\d+)/;

    my $format = ( "%03i" x @a );
    return sprintf( $format, @a ) cmp sprintf( $format, @b );
}

sub show_ref {
    my ( $self, $git ) = @_;
    my %refs;
    my $cmd = $git->command( 'show-ref' );
    while ( defined( my $line = readline $cmd->stdout ) ) {
        # <SHA1 hash> <symbolic ref>
        my ( $ref_id, $ref_name ) = split /\s+/, $line;
        $refs{ $ref_name } = $ref_id;
    }
    return wantarray ? %refs : \%refs;
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

sub has_remote {
    my ( $self, $git, $name ) = @_;
    return grep { $_ eq $name } $git->run( 'remote' );
}

sub has_branch {
    my ( $self, $git, $name ) = @_;
    return grep { $_ eq $name } map { s/[*]?\s+//; $_ } $git->run( 'branch' );
}

sub opt_spec {
    return (
        [ 'repo_dir:s' => 'The path to the release repository' ],
        [ 'prefix:s' => 'The release version prefix, like "v" or "ops-"' ],
    );
}

sub execute {
    my ( $self, $opt, $args ) = @_;

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
