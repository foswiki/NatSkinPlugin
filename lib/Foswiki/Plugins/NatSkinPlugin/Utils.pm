###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2017 MichaelDaum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
###############################################################################

package Foswiki::Plugins::NatSkinPlugin::Utils;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();
use Encode();

our %maxRevs = ();    # cache for getMaxRevision()

###############################################################################
sub init {

  # init caches
  %maxRevs = ();
}

###############################################################################
sub makeParams {
  my $query = shift;

  $query ||= Foswiki::Func::getCgiQuery();

  my @params = ();
  my $anchor = '';

  foreach my $key ($query->param) {
    next if $key eq 'POSTDATA';
    my $val = $query->param($key) || '';

    if ($key eq '#') {
      $anchor .= '#' . Foswiki::urlEncode($val);
    } else {
      push(@params, Foswiki::urlEncode($key) . '=' . Foswiki::urlEncode($val));
    }
  }

  return join(";", @params) . $anchor;
}

###############################################################################
sub getPrevRevision {
  my ($thisWeb, $thisTopic, $numberOfRevisions) = @_;

  my $request = Foswiki::Func::getCgiQuery();
  my $rev;
  $rev = $request->param("rev") if $request;
  $rev =~ s/[^\d]//g;

  $numberOfRevisions ||= $Foswiki::cfg{NumberOfRevisions};

  $rev = getMaxRevision($thisWeb, $thisTopic) unless $rev;
  $rev =~ s/r?1\.//go;    # cut major
  if ($rev > $numberOfRevisions) {
    $rev -= $numberOfRevisions;
    $rev = 1 if $rev < 1;
  } else {
    $rev = 1;
  }

  return $rev;
}

###############################################################################
sub getMaxRevision {
  my ($thisWeb, $thisTopic) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  $thisWeb = $session->{webName} unless $thisWeb;
  $thisTopic = $session->{topicName} unless $thisTopic;

  my $maxRev = $maxRevs{"$thisWeb.$thisTopic"};
  return $maxRev if defined $maxRev;

  (undef, undef, $maxRev) = Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic);
  $maxRev = 1 unless defined $maxRev;

  $maxRev =~ s/r?1\.//go;    # cut 'r' and major
  $maxRevs{"$thisWeb.$thisTopic"} = $maxRev;
  return $maxRev;
}

###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  $thisWeb = $session->{webName} unless $thisWeb;
  $thisTopic = $session->{topicName} unless $thisTopic;

  my $request = Foswiki::Func::getCgiQuery();
  my $rev;
  if ($request) {
    $rev = $request->param("rev");
    unless (defined $rev) {
      my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();
      if ($themeEngine->{skinState}{'action'} =~ /compare|rdiff|diff/) {
        my $rev1 = $request->param("rev1");
        my $rev2 = $request->param("rev2");
        if ($rev1 && $rev2) {
          $rev1 =~ s/[^\d]//g;
          $rev2 =~ s/[^\d]//g;
          $rev = ($rev1 > $rev2) ? $rev1 : $rev2;
        }
      }
    }
  }

  $rev = getMaxRevision($thisWeb, $thisTopic) unless $rev;
  $rev =~ s/[^\d]//g;

  return $rev;
}

###############################################################################
sub getScriptUrlPath {
  my $script = shift;
  my $web = shift;
  my $topic = shift;

  my $session = $Foswiki::Plugins::SESSION;
  $web ||= $session->{webName};
  $topic ||= $session->{topicName};

  return $session->getScriptUrl(0, $script, $web, $topic, @_);
}

1;
