#!/usr/bin/env perl
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build('NatSkinPlugin');
$build->build($build->{target});

