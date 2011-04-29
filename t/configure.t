# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More 0.96;

my $NAME = 'Author::RWSTAUNER';
my $BNAME = "\@$NAME";
my $mod = "Dist::Zilla::PluginBundle::$NAME";
eval "require $mod" or die $@;

# get default MetaNoIndex hashref
my $noindex = (grep { ref($_) && $_->[0] =~ 'MetaNoIndex' }
  @{ init_bundle({})->plugins })[0]->[-1];
my $noindex_dirs = $noindex->{directory};

# test attributes that change plugin configurations
my %default_exp = (
  CompileTests            => {fake_home => 1},
  PodWeaver               => {config_plugin => $BNAME},
  AutoPrereqs             => {},
  MetaNoIndex             => {%$noindex, directory => [@$noindex_dirs]},
  'MetaProvides::Package' => {meta_noindex => 1},
);

foreach my $test (
  [{}, {%default_exp}],
  [{'skip_prereqs'     => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
  [{'AutoPrereqs:skip' => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
  [{'MetaNoIndex:directory'  => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => [@$noindex_dirs, 'goober']} }],
  [{'MetaNoIndex:directory@' => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => ['goober']} }],
  [{'CompileTests->fake_home' => 0},            { %default_exp, CompileTests => {fake_home => 0} }],
  [{'MetaProvides::Package:meta_noindex' => 0}, { %default_exp, 'MetaProvides::Package' => {meta_noindex => 0} }],
  [{weaver_config => '@Default', 'MetaNoIndex:directory[]' => 'arr'}, {
    PodWeaver => {config_plugin => '@Default'},
    MetaNoIndex => {%$noindex, directory => ['arr']} }],
){
  my ($config, $exp) = @$test;

  my @plugins = @{init_bundle($config)->plugins};

  foreach my $plugin ( @plugins ){
    my ($moniker, $name, $payload) = @$plugin;
    my ($plugname) = ($moniker =~ /^$BNAME\/(.+)$/);

    if( exists $exp->{$plugname} ){
      is_deeply($payload, $exp->{$plugname}, 'expected configuration')
    }
  }
}

# test attributes that alter which plugins are included
{
  my $bundle = init_bundle({});
  my $test_name = 'expected plugins included';

  my $has_ok = sub {
    ok( has_plugin($bundle, @_), "expected plugin included: $_[0]");
  };
  my $has_not = sub {
    ok(!has_plugin($bundle, @_), "plugin expectedly not found: $_[0]");
  };
  &$has_ok('PodWeaver');
  &$has_ok('PodWeaver');
  &$has_ok('AutoPrereqs');
  &$has_ok('CompileTests');
  &$has_ok('ExtraTests');
  &$has_not('FakeRelease');
  &$has_ok('UploadToCPAN');
  &$has_ok('CompileTests');

  $bundle = init_bundle({auto_prereqs => 0});
  &$has_not('AutoPrereqs');

  $bundle = init_bundle({fake_release => 1});
  &$has_ok('FakeRelease');
  &$has_not('UploadToCPAN');

  $bundle = init_bundle({is_task => 1});
  &$has_ok('TaskWeaver');
  &$has_not('PodWeaver');

  $bundle = init_bundle({releaser => 'Goober'});
  &$has_ok('Goober');
  &$has_not('UploadToCPAN');

  $bundle = init_bundle({skip_plugins => '\b(CompileTests|ExtraTests|GenerateManifestSkip)$'});
  &$has_not('CompileTests');
  &$has_not('ExtraTests');
  &$has_not('GenerateManifestSkip', 1);

  $bundle = init_bundle({disable_tests => 'EOLTests,CompileTests'});
  &$has_not('EOLTests');
  &$has_not('CompileTests');
  &$has_ok('NoTabsTests');
}

# test releaser
foreach my $releaser (
  [{},                                        'UploadToCPAN'],
  [{fake_release => 1},                       'FakeRelease'],
  [{releaser => 'Goober'},                    'Goober'],
  # fake_release wins
  [{releaser => 'Goober', fake_release => 1}, 'FakeRelease'],
){
  my ($config, $exp) = @$releaser;
  releaser_is(init_bundle($config), $exp);
  # env always overrides
  local $ENV{DZIL_FAKERELEASE} = 1;
  releaser_is(init_bundle($config), 'FakeRelease');
}

done_testing;

# helper subs
sub has_plugin {
  my ($bundle, $plug, $by_name) = @_;
  # default to plugin module, but allow searching by name
  my $index = $by_name ? 0 : 1;
  # should use List::Util::any
  scalar grep { $_->[$index] =~ /\b($plug)$/ } @{$bundle->plugins};
}
sub init_bundle {
  my $bundle = $mod->new(name => $BNAME, payload => $_[0]);
  isa_ok($bundle, $mod);
  $bundle->configure;
  return $bundle;
}
sub releaser_is {
  my ($bundle, $exp) = @_;
  # ignore any after-release plugins at the end
  my @after = qw(
    Git::
    InstallRelease
  );
  my $skip = qr/^Dist::Zilla::Plugin::(${\join('|', @after)})/;
  # NOTE: just looking for the last plugin in the array is fragile
  my $releaser = (grep { $_->[1] !~ $skip } reverse @{$bundle->plugins})[0];
  like($releaser->[1], qr/\b$exp$/, "expected releaser: $exp");
}
