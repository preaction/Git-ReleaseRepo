
use strict;
use warnings;
use Test::Most;
use Test::Git;
use Cwd qw( getcwd );
my $CWD = getcwd;
END {
    chdir $CWD;
};
use File::Spec::Functions qw( catfile );
use File::Slurp qw( write_file );
use Git::ReleaseRepo;
use Git::ReleaseRepo::Test qw( run_cmd get_cmd_result );

my $foo_repo = test_repository;
my $foo_readme = catfile( $foo_repo->work_tree, 'README' );
write_file( $foo_readme, 'Foo version 0.0' );
$foo_repo->run( add => $foo_readme );
$foo_repo->run( commit => -m => 'Added readme' );

subtest 'requires a version_prefix' => sub {
    chdir $foo_repo->work_tree;
    my $result = get_cmd_result( 'init' );
    ok $result->error;
    isnt $result->exit_code, 0;
};

done_testing;
