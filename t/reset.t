
use Test::Most;

# Set up
# TODO

subtest 'reset a bugfix release' => sub {
    chdir $rel_root;
    my $result = run_cmd( 'reset' );
    # Resets the last release

};

subtest 'cannot reset a non-tip release' => sub {
    chdir $rel_root;
    my $result = run_cmd( 'reset', 'v0.1.0' );
    # Error
};

subtest 'reset a specific release' => sub {
    chdir $rel_root;
    my $result = run_cmd( 'reset', 'v0.1.1' );
    # Resets the specific release
};

subtest 'reset a minor release' => sub {
    chdir $rel_root;
    my $result = run_cmd( 'reset' );
    # Reset's v0.2.0
    # Also deletes the branch
};

subtest 'reset an already-pushed release' => sub {
    # You do it, you can UNDO it!

};

done_testing;
