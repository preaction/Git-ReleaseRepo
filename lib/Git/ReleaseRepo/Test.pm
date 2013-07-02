package Git::ReleaseRepo::Test;

use strict;
use warnings;
use Test::Most;
use App::Cmd::Tester::CaptureExternal qw( test_app );
use Sub::Exporter -setup => {
    exports => [qw(
        run_cmd is_repo_clean last_commit repo_branches repo_tags repo_refs
        current_branch is_current_tag
    )],
};

sub run_cmd {
    my $result = test_app( 'Git::ReleaseRepo' => \@_ );
    is $result->error, undef, 'no error';
    ok !$result->stderr, 'ran with no errors or warnings' or do {
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

1;
