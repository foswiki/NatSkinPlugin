# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2025 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::Utils;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::Utils

this is a bunch of static helper functions that are imported by various modules of NatSkinPlugin

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();
use Encode();

use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw(makeParams getPrevRevision getMaxRevision getCurRevision getScriptUrlPath getFormName);
our %EXPORT_TAGS = (
  all => [qw(makeParams getPrevRevision getMaxRevision getCurRevision getScriptUrlPath getFormName)]
);

=begin TML

---++ getFormName($web, $topic) -> $formName

returns the form name of a given web.topic

=cut

sub getFormName {
  my ($web, $topic) = @_;

  return unless defined $web && defined $topic;

  $web =~ s/\//./g;
  my $key = "$web.$topic";

  my $session = $Foswiki::Plugins::SESSION;
  my $formName = $session->{_NatSkin}{cache}{formNames}{$key};
  unless ($formName) {
    my ($topicObj) = Foswiki::Func::readTopic($web, $topic);
    $session->{formNames}{$key} = $formName = ($topicObj?$topicObj->getFormName:"");
  }

  return $formName;
}

=begin TML

---++ makeParams($query) -> $params

returns url parameters 

=cut

sub makeParams {
  my $query = shift;

  $query ||= Foswiki::Func::getRequestObject();

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

=begin TML

---++ getPrevRevision($web, $topic, $numOfRevs) -> $rev

TODO

=cut

sub getPrevRevision {
  my ($thisWeb, $thisTopic, $numberOfRevisions) = @_;

  my $request = Foswiki::Func::getRequestObject();
  my $rev;
  $rev = $request->param("rev") if $request;
  $rev =~ s/[^\d]//g;

  $numberOfRevisions ||= $Foswiki::cfg{NumberOfRevisions};

  $rev = getMaxRevision($thisWeb, $thisTopic) unless $rev;
  $rev =~ s/r?1\.//g;    # cut major
  if ($rev > $numberOfRevisions) {
    $rev -= $numberOfRevisions;
    $rev = 1 if $rev < 1;
  } else {
    $rev = 1;
  }

  return $rev;
}

=begin TML

---++ getMaxRevision($web, $topic) -> $rev

returns the max revision available for a given web.topic
results are cached

=cut

sub getMaxRevision {
  my ($thisWeb, $thisTopic) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  $thisWeb = $session->{webName} unless $thisWeb;
  $thisTopic = $session->{topicName} unless $thisTopic;

  my $maxRev = $session->{_NatSkin}{cache}{maxRevs}{"$thisWeb.$thisTopic"};
  return $maxRev if defined $maxRev;

  (undef, undef, $maxRev) = Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic);
  $maxRev = 1 unless defined $maxRev;

  $maxRev =~ s/r?1\.//g;    # cut 'r' and major
  $session->{_NatSkin}{cache}{maxRevs}{"$thisWeb.$thisTopic"} = $maxRev;
  return $maxRev;
}

=begin TML

---++ getCurRevision($web, $topic) -> $rev


=cut

sub getCurRevision {
  my ($thisWeb, $thisTopic) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  $thisWeb = $session->{webName} unless $thisWeb;
  $thisTopic = $session->{topicName} unless $thisTopic;

  my $request = Foswiki::Func::getRequestObject();
  my $rev;
  if ($request) {
    $rev = $request->param("rev");
    unless (defined $rev) {
      my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
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

=begin TML

---++ getScriptUrlPath($script, $web, $topic) -> $url

compatibiliy for Foswiki::getScriptUrlPath(). note that other than
Foswiki::Func::getScriptUrl() this method always returns relative urls
no matter in which context the render is

=cut

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
