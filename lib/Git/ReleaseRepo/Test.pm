package Git::ReleaseRepo::Test;

use strict;
use warnings;
use Test::Most;
use Test::Git;
use File::Spec::Functions qw( catfile catdir );
use File::Slurp qw( write_file );
use App::Cmd::Tester::CaptureExternal 'test_app';
use Sub::Exporter -setup => {
    exports => [qw(
        get_cmd_result run_cmd is_repo_clean last_commit repo_branches repo_tags repo_refs
        current_branch is_current_tag create_module_repo
    )],
};

sub get_cmd_result {
    return test_app( 'Git::ReleaseRepo' => \@_ );
}

sub run_cmd {
    my $result = get_cmd_result( @_ );
    ok !$result->stderr, 'nothing on stderr' or diag $result->stderr;
    is $result->error, undef, 'no error' or diag $result->error;
    is $result->exit_code, 0, 'ran with no errors or warnings' or do {
        diag $result->stdout; diag $result->stderr
    };
    return $result;
}

sub is_repo_clean($;$) {
    my ( $git, $message ) = @_;
    $message ||= 'repository is clean';
    my $cmd = $git->command( status => '--porcelain' );
    my @lines = readline $cmd->stdout;
    is scalar @lines, 0, $message or diag "Found:\n" . join "", @lines;
}

sub last_commit($) {
    my ( $git ) = @_;
    my $cmd = $git->command( 'diff-tree' => '--raw', '--root', 'HEAD' );
    my @lines = readline $cmd->stdout;
    #; use Data::Dumper;
    #; print Dumper \@lines;
    my @changes = map {; { 
                    mode_src => $_->[0], 
                    mode_dst => $_->[1], 
                    sha1_src => $_->[2],
                    sha1_dst => $_->[3],
                    status   => $_->[4],
                    path_src => $_->[5],
                    path_dst => $_->[6],
                } }
                map { [ split /\s+/, $_ ] }
                map { s/^://; $_ }
                @lines[1..$#lines];
    #; diag explain \@changes;
    return @changes;
}

sub repo_branches($) {
    my ( $git ) = @_;
    my $cmd = $git->command( 'branch' );
    # [* ] <branch>
    return map { chomp; $_ } map { s/^[*\s]\s//; $_ } readline $cmd->stdout;
}

sub repo_tags($) {
    my ( $git ) = @_;
    my $cmd = $git->command( 'tag' );
    return map { chomp; $_ } readline $cmd->stdout;
}

sub repo_refs($) {
    my ( $git ) = @_;
    my $cmd = $git->command( 'show-ref' );
    return map { $_->[1], $_->[0] } map { [split] } readline $cmd->stdout;
}

sub current_branch($) {
    my ( $git ) = @_;
    my $cmd = $git->command( 'branch' );
    # [* ] <branch>
    return map { chomp; $_ } map { s/^[*\s]\s//; $_ } grep { /^[*]/ } readline $cmd->stdout;
}

sub is_current_tag($$) {
    my ( $git, $tag ) = @_;
    my $cmd = $git->command( 'describe', '--tags', '--match', $tag );
    # <tag>
    # OR
    # <tag>-<commits since tag>-<shorthash>
    my $line = readline $cmd->stdout;
    if ( $cmd->exit ) {
        fail "$tag is not current tag: " . readline $cmd->stderr;
    }
    #print "describe: $line\n";
    chomp $line;
    is $line, $tag, "commit is tagged '$tag'";
}

sub create_module_repo {
    my $repo = test_repository;
    my $readme = catfile( $repo->work_tree, 'README' );
    write_file( $readme, 'TEST' );
    $repo->run( add => $readme );
    $repo->run( 'commit', -m => 'commit readme' );
    return $repo;
}

1;
