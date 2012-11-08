
use Module::Build;

my $build = Module::Build->new(
    module => 'Git::ReleaseRepo',
    requires => {
        'Git::Repository' => 1.26,
        'App::Cmd'        => 0.318,
        'File::HomeDir'   => 1.00,
        'YAML::Tiny'      => 1.51,
    },
    license => 'perl',
);
$build->create_build_script;
