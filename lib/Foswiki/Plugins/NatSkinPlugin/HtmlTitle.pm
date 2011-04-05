###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2010 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
use strict;
use warnings;

use Foswiki::Func ();

sub render {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theSep = $params->{separator} || ' - ';
  my $theWikiToolName = $params->{wikitoolname} || 'on';

  if ($theWikiToolName eq 'on') {
    $theWikiToolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME") || 'Wiki';
    $theWikiToolName = $theSep.$theWikiToolName;
  } elsif ($theWikiToolName eq 'off') {
    $theWikiToolName = '';
  } else {
    $theWikiToolName = $theSep.$theWikiToolName;
  }

  my $theFormat = $params->{_DEFAULT};

  unless (defined $theFormat) {
    my $htmlTitle = Foswiki::Func::getPreferencesValue("HTMLTITLE");
    return $htmlTitle if $htmlTitle;
  }

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $params->{topic} || $theTopic);
  $web = join($theSep, reverse split(/[\.\/]/, $web));

  my $topicTitle = $params->{title};

  unless (defined $topicTitle) {
    require Foswiki::Plugins::DBCachePlugin;
    $topicTitle = Foswiki::Plugins::DBCachePlugin::getTopicTitle($web, $topic);
  }

  $theFormat = '$title$sep$web$wikitoolname' unless defined $theFormat;
  $theFormat =~ s/\$sep/$theSep/g;
  $theFormat =~ s/\$wikitoolname/$theWikiToolName/g;
  $theFormat =~ s/\$web/$web/g;
  $theFormat =~ s/\$title/$topicTitle/g;

  return Foswiki::Func::decodeFormatTokens($theFormat);
}

1;

