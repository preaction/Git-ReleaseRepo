
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Git::ReleaseRepo',
    requires => {
        'Git::Repository' => 1.26,
        'App::Cmd'        => 0.318,
        'File::HomeDir'   => 1.00,
        'YAML::Tiny'      => 1.51,
        'File::HomeDir'   => 0,
        'File::Path'      => 0,
    },
    test_requires => {
        'Test::Most'      => 0,
        'File::Temp'      => 0,
        'File::Spec::Functions' => 0,
        'File::Slurp'     => 0,
    },
    license => 'perl',
);
$build->create_build_script;
