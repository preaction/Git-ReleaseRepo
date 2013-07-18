package Git::ReleaseRepo::Command::pull;
# ABSTRACT: Update a release repository

use Moose;
extends 'Git::ReleaseRepo::Command';

override usage_desc => sub {
    my ( $self ) = @_;
    return super();
};

sub description {
    return 'Update a deployed release repository';
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    return $self->usage_error( "Too many arguments" ) if ( @$args > 0 );
}

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'branch=s' => 'Specify the release branch to deploy. Defaults to the latest release branch.' ],
        [ 'master' => 'Deploy the "master" version of the repository and all submodules, for testing.' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $git         = $self->git;
    my $branch      = $opt->{master} ? "master"
                    : $opt->{branch} ? $opt->{branch}
                    : $self->config->{track} ? $self->config->{track}
                    : $git->current_branch;
    my @repos = ( $self->git, map { $self->git->submodule_git( $_ ) } keys $self->git->submodule );
    my $version; # Filled in after the first pull
    for my $repo ( @repos ) {
        if ( $repo->has_remote( 'origin' ) ) {
            my $cmd = $repo->command( checkout => $branch );
            my @stderr = readline $cmd->stderr;
            my @stdout = readline $cmd->stdout;
            $cmd->close;
            if ( $cmd->exit != 0 ) {
                die "Could not checkout branch $branch\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                    . "\nSTDOUT: " . ( join "\n", @stdout );
            }
            $cmd = $repo->command( qw(fetch origin) );
            @stderr = readline $cmd->stderr;
            @stdout = readline $cmd->stdout;
            $cmd->close;
            if ( $cmd->exit != 0 ) {
                die "Could not fetch origin\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                    . "\nSTDOUT: " . ( join "\n", @stdout );
            }
            $cmd = $repo->command( qw(pull origin), $branch );
            @stderr = readline $cmd->stderr;
            @stdout = readline $cmd->stdout;
            $cmd->close;
            if ( $cmd->exit != 0 ) {
                die "Could not pull branch $branch from origin\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                    . "\nSTDOUT: " . ( join "\n", @stdout );
            }
        }
        $version ||= $opt->{master}  ? "master"
                 : $self->config->{track} ? $git->latest_version( $branch )
                 : $branch;
        my $cmd = $repo->command( checkout => $version );
        my @stderr = readline $cmd->stderr;
        my @stdout = readline $cmd->stdout;
        $cmd->close;
        if ( $cmd->exit != 0 ) {
            die "Could not checkout $version\nEXIT: " . $cmd->exit . "\nSTDERR: " . ( join "\n", @stderr )
                . "\nSTDOUT: " . ( join "\n", @stdout );
        }
    }
};

1;
__END__

