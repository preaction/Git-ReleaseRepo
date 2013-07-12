
use Test::Most;
use Cwd qw( getcwd );
use File::Temp;
use Test::Git;
use Git::ReleaseRepo::Test qw( run_cmd get_cmd_result create_module_repo repo_tags repo_branches );
use File::Spec::Functions qw( catdir catfile );
use File::Slurp qw( write_file );
use Git::ReleaseRepo;

my $cwd = getcwd;
END { chdir $cwd };

# Set up
my $module_repo = create_module_repo;
my $module_readme = catfile( $module_repo->work_tree, 'README' );
my $origin_repo = test_repository;
chdir $origin_repo->work_tree;
run_cmd( 'init', '--version_prefix', 'v' );
run_cmd( add => module => $module_repo->work_tree );
run_cmd( 'commit' );
my $clone_dir = File::Temp->newdir;
my $clone_repo;

subtest 'setup' => sub {
    chdir $clone_dir;
    Git::Repository->run( clone => $origin_repo->work_tree, 'clone' );
    chdir catdir( $clone_dir, 'clone' );
    my $result = run_cmd( 'init', '--version_prefix', 'v' );
    $clone_repo = Git::Repository->new( work_tree => catdir( $clone_dir, 'clone' ) );
};

subtest 'push a release repo' => sub {
    write_file( $module_readme, 'TEST ONE' );
    $module_repo->run( add => $module_readme );
    $module_repo->run( 'commit', -m => 'test one' );

    chdir $clone_repo->work_tree;
    run_cmd( add => 'module' );
    run_cmd( 'commit' );

    subtest 'origin repo should have the branch and tag' => sub {
        my @branches = repo_branches( $origin_repo );
        cmp_deeply \@branches, superbagof( 'v0.2' );
        my @tags = repo_tags( $origin_repo );
        cmp_deeply \@tags, superbagof( 'v0.2.0' );
    };
    subtest 'module repo should have the branch and tag' => sub {
        my @branches = repo_branches( $module_repo );
        cmp_deeply \@branches, superbagof( 'v0.2' );
        my @tags = repo_tags( $module_repo );
        cmp_deeply \@tags, superbagof( 'v0.2.0' );
    };
};

subtest 'problem push, not fast-forward (module)' => sub {
    # Add a change to a module
    write_file( $module_readme, 'TEST TWO' );
    $module_repo->run( add => $module_readme );
    $module_repo->run( 'commit', -m => 'test two' );

    # Add change to release
    chdir $clone_repo->work_tree;
    my $result = run_cmd( add => 'module' );
    $result = run_cmd( 'commit' );

    # Add another change to module
    write_file( $module_readme, 'TEST TWO A' );
    $module_repo->run( add => $module_readme );
    $module_repo->run( 'commit', -m => 'test two a' );

    # Try to push release
    chdir $clone_repo->work_tree;
    $result = get_cmd_result( 'push' );
    isnt $result->exit_code, 0;
    like $result->error, qr{ERROR} or diag $result->error;
};

subtest 'problem push, not fast-forward (origin)' => sub {
    # Add a change to a module
    write_file( $module_readme, 'TEST THREE' );
    $module_repo->run( add => $module_readme );
    $module_repo->run( 'commit', -m => 'test three' );

    # Add change to release
    chdir $clone_repo->work_tree;
    my $result = run_cmd( add => 'module' );
    $result = run_cmd( 'commit' );

    # Add another change to module
    write_file( $module_readme, 'TEST THREE A' );
    $module_repo->run( add => $module_readme );
    $module_repo->run( 'commit', -m => 'test three a' );

    # Change should be in origin
    chdir $origin_repo->work_tree;
    $result = run_cmd( add => 'module' );
    $result = run_cmd( 'commit' );

    # Try to push release
    chdir $clone_repo->work_tree;
    $result = get_cmd_result( 'push' );
    isnt $result->exit_code, 0;
    like $result->error, qr{ERROR} or diag $result->error;
};

chdir $cwd;

done_testing;
