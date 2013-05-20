
use strict;
use warnings;
use Test::Most;
use Test::Git;

use File::Spec::Functions qw( catdir catfile );
use File::Slurp qw( read_file write_file );

my $foo_repo = test_repository;
my $bar_repo = test_repository;
my $rel_repo = test_repository;
#my $rel_repo = test_repository( temp => [ CLEANUP => 0 ] );
#END { diag "Work tree: " . $rel_repo->work_tree; }

my $foo_readme = catfile( $foo_repo->work_tree, 'README' );
write_file( $foo_readme, 'Foo version 1.0' );
$foo_repo->run( add => $foo_readme );
$foo_repo->run( commit => -m => 'Added readme' );

my $bar_readme = catfile( $bar_repo->work_tree, 'README' );
write_file( $bar_readme, 'Bar version 1.0' );
$bar_repo->run( add => $bar_readme );
$bar_repo->run( commit => -m => 'Added readme' );

use Git::ReleaseRepo;
use App::Cmd::Tester qw( test_app );

sub run_cmd {
    my $result = test_app( @_ );
    is $result->error, undef, 'no error';
    ok !$result->stderr, 'ran with no errors or warnings' or diag $result->stderr;
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

subtest 'add new module' => sub {
    my $result = run_cmd( 'Git::ReleaseRepo' => [ 'add', '--repo_dir', $rel_repo->work_tree, 'foo', $foo_repo->work_tree ] );

    subtest 'repository is correct' => sub {
        is_repo_clean $rel_repo;
        my @changes = last_commit $rel_repo;
        is scalar @changes, 2, 'only two changes were made';
        cmp_deeply \@changes,
            bag( 
                superhashof( { path_src => '.gitmodules' } ),
                superhashof( { path_src => 'foo' } ),
            ),
            'changes to .gitmodules and foo';

        my $gitmodules = read_file( catfile( $rel_repo->work_tree, '.gitmodules' ) );
        like $gitmodules, qr{\[submodule\s+"foo"\]\s+path\s*=\s*foo}s, 'module has right name and path';
    };

    subtest 'module status is changed' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree ] );
        like $result->{stdout}, qr/foo changed/, 'foo has been changed';
        unlike $result->{stdout}, qr/can add/, 'but cannot be updated';
    };
};

subtest 'update module' => sub {
    write_file( $foo_readme, 'Foo version 2.0' );
    $foo_repo->run( add => $foo_readme );
    $foo_repo->run( commit => -m => 'Added readme' );

    subtest 'module status is out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree ] );
        like $result->{stdout}, qr/foo changed/, 'foo has not been released yet';
        like $result->{stdout}, qr/can add/, 'and can be updated';
    };

    my $result = test_app( 'Git::ReleaseRepo' => [ 'add', '--repo_dir', $rel_repo->work_tree, 'foo' ] );

    subtest 'module status is no longer out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree ] );
        like $result->{stdout}, qr/foo changed/, 'foo has not been released yet';
        unlike $result->{stdout}, qr/can add/, 'and can be updated';
    };
};

subtest 'first release' => sub {
    my $result = run_cmd( 'Git::ReleaseRepo' => [ 'release', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );

    subtest 'release repository is correct' => sub {
        is_repo_clean $rel_repo;
        # Has release branch and release tag
        my @branches = grep { $_ ne 'master' } repo_branches $rel_repo;
        cmp_deeply \@branches, bag( 'v0.1' ), 'first minor release cycle, with prefix';

        my @tags = repo_tags $rel_repo;
        cmp_deeply \@tags, bag( 'v0.1.0' ), 'first minor release, with prefix';
    };

    subtest 'module repository is correct' => sub {
        # Got the branch and tag pushed
        is_repo_clean $foo_repo;
        my @branches = grep { $_ ne 'master' } repo_branches $foo_repo;
        cmp_deeply \@branches, bag( 'v0.1' ), 'first minor release cycle, with prefix';

        my @tags = repo_tags $foo_repo;
        cmp_deeply \@tags, bag( 'v0.1.0' ), 'first minor release, with prefix';
    };

    subtest 'module status is unchanged' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo has been released';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };
};

subtest 'add bugfix' => sub {
    # Foo has a bugfix
    my $cmd = $foo_repo->command( checkout => 'v0.1' );
    $cmd->close;
    if ( $cmd->exit != 0 ) {
        fail "Could not checkout Foo 'v0.1'.\nSTDERR: " . $cmd->stderr;
    }
    write_file( $foo_readme, 'Foo version 2.1' );
    $foo_repo->run( add => $foo_readme );
    $foo_repo->run( commit => -m => 'Added bugfix' );
    $foo_repo->command( checkout => 'master' );

    subtest 'bugfix status is out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--bugfix', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo "v0.1" has not been released';
        like $result->{stdout}, qr/can add/, 'but can be updated';
    };

    subtest 'release status is also out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo "master" has not been changed';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };

    subtest 'add bugfix update' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'add', '--bugfix', '--repo_dir', $rel_repo->work_tree, 'foo', '--prefix', 'v' ] );
    };

    subtest 'repo branch "v0.1" status is correct' => sub {
        my $cmd;
        my %refs = repo_refs $rel_repo;
        isnt $refs{'refs/heads/v0.1'}, $refs{'refs/tags/v0.1.0'}, "we've moved past v0.1.0";
        $cmd = $rel_repo->command( checkout => 'v0.1' );
        $cmd->close;
        $cmd = $rel_repo->command( submodule => 'update', '--init' );
        $cmd->close;
        my @changes = last_commit $rel_repo;
        is scalar @changes, 1, 'only one change was made';
        is $changes[0]{path_src}, 'foo', 'only change is to the foo module';
        is $changes[0]{status}, 'M', 'foo was modified';
    };

    subtest 'repo branch "master" status is correct' => sub {
        my $cmd;
        $cmd = $rel_repo->command( checkout => 'master' );
        $cmd->close;
        my %refs = repo_refs $rel_repo;
        is $refs{'refs/heads/master'}, $refs{'refs/tags/v0.1.0'}, "we have not moved past v0.1.0";
    };

    subtest 'bugfix status is changed, not out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--bugfix', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        like $result->{stdout}, qr/foo changed/, 'foo "v0.1" has been updated';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };

    subtest 'release status is still out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo "master" has not been changed';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };
};

done_testing;
__END__

subtest 'update non-bugfix' => sub {
    subtest 'add new module' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'add', '--repo_dir', $rel_repo->work_tree, 'bar', $bar_repo->work_tree ] );
    };
    subtest 'release status is changed, not out-of-date' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        like $result->{stdout}, qr/bar changed/, 'bar has been updated';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated further';
    };
    subtest 'bugfix status is same as it was' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--bugfix', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/bar changed/, 'bar has not been changed';
        like $result->{stdout}, qr/foo changed/, 'foo has been updated';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };
};

subtest 'bugfix release' => sub {
    # Only foo is released
    my $result = run_cmd( 'Git::ReleaseRepo' => [ 'release', '--bugfix', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );

    subtest 'release repository is correct' => sub {
        is_repo_clean $rel_repo;
        # Has release branch and release tag
        my @branches = grep { $_ ne 'master' } repo_branches $rel_repo;
        cmp_deeply \@branches, bag( 'v0.1' ), 'first minor release cycle, with prefix';

        my @tags = repo_tags $rel_repo;
        cmp_deeply \@tags, bag('v0.1.0','v0.1.1'), 'another tag for the bugfix release';
    };

    subtest 'module repository is correct' => sub {
        # Got the branch and tag pushed
        is_repo_clean $foo_repo;
        my @branches = grep { $_ ne 'master' } repo_branches $foo_repo;
        cmp_deeply \@branches, bag( 'v0.1' ), 'first minor release cycle, with prefix';

        my @tags = repo_tags $foo_repo;
        cmp_deeply \@tags, bag('v0.1.0','v0.1.1'), 'another tag for the bugfix release';
    };

    subtest 'bugfix branch is clean' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--bugfix', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo has been released';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };

    subtest 'release branch is same as it was' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        like $result->{stdout}, qr/bar changed/, 'bar has been updated';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated further';
        unlike $result->{stdout}, qr/foo changed/, 'no changes made to foo';
    };
};

subtest 'second release' => sub {
    my $result = run_cmd( 'Git::ReleaseRepo' => [ 'release', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );

    subtest 'release repository is correct' => sub {
        is_repo_clean $rel_repo;
        my @branches = grep { $_ ne 'master' } repo_branches $rel_repo;
        cmp_deeply \@branches, bag( 'v0.1', 'v0.2' ), 'two releases now';

        my @tags = repo_tags $rel_repo;
        cmp_deeply \@tags, bag('v0.1.0','v0.1.1','v0.2.0'), 'another tag for the new minor release';
    };

    subtest 'foo module repository is correct' => sub {
        is_repo_clean $foo_repo;
        my @branches = grep { $_ ne 'master' } repo_branches $foo_repo;
        cmp_deeply \@branches, bag( 'v0.1', 'v0.2' ), 'two releases now';

        my @tags = repo_tags $foo_repo;
        cmp_deeply \@tags, bag('v0.1.0','v0.1.1','v0.2.0'), 'another tag for the new minor release';
    };

    subtest 'bar module repository is correct' => sub {
        is_repo_clean $bar_repo;
        my @branches = grep { $_ ne 'master' } repo_branches $bar_repo;
        is scalar @branches, 1, 'one branch created';
        cmp_deeply \@branches, bag( 'v0.2' ), 'only one release in the bar module';

        my @tags = repo_tags $bar_repo;
        is scalar @tags, 1, 'one tag created';
        cmp_deeply \@tags, bag('v0.2.0'), 'only one tag for the bar module';
    };

    subtest 'module status is unchanged' => sub {
        my $result = run_cmd( 'Git::ReleaseRepo' => [ 'status', '--repo_dir', $rel_repo->work_tree, '--prefix', 'v' ] );
        unlike $result->{stdout}, qr/foo changed/, 'foo has been released';
        unlike $result->{stdout}, qr/bar changed/, 'bar has been released';
        unlike $result->{stdout}, qr/can add/, 'and can not be updated';
    };
};

done_testing;
