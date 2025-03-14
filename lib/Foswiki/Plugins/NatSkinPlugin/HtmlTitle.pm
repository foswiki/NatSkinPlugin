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

package Foswiki::Plugins::NatSkinPlugin::HtmlTitle;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::HtmlTitle

service class to render the HTMLTITLE macro

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::MultiLingualPlugin();

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

=begin TML

---++ render($params, $topic, $web) -> $html

implements the HTMLTITLE macro

=cut

sub render {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $theSep = $params->{separator} || ' - ';
  my $theWikiToolName = $params->{wikitoolname} || 'on';
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $params->{topic} || $theTopic);

  if ($theWikiToolName eq 'on') {
    $theWikiToolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME") || 'Wiki';
    $theWikiToolName = $theSep . $theWikiToolName;
  } elsif ($theWikiToolName eq 'off') {
    $theWikiToolName = '';
  } else {
    $theWikiToolName = $theSep . $theWikiToolName;
  }

  my $theFormat = $params->{_DEFAULT};
  $theFormat = $params->{format} unless defined $theFormat;

  my $doTranslate = Foswiki::Func::isTrue($params->{translate}, 0);

  unless (defined $theFormat) {
    my $htmlTitle = Foswiki::Func::getPreferencesValue("HTMLTITLE");
    return $htmlTitle if $htmlTitle;
  }

  my $webTitle = join($theSep, map {
    $doTranslate ? Foswiki::Plugins::MultiLingualPlugin::translate($_, $_, $Foswiki::cfg{HomeTopicName}): $_
  } reverse split(/[\.\/]/, $web));

  my $topicTitle = $params->{title};
  $topicTitle = Foswiki::Func::getTopicTitle($web, $topic) unless defined $topicTitle;
  $topicTitle = Foswiki::Plugins::MultiLingualPlugin::translate($topicTitle, $web, $topic) if $doTranslate;

  $theFormat = '$title$sep$webtitle$wikitoolname' unless defined $theFormat;
  $theFormat =~ s/\$sep\b/$theSep/g;
  $theFormat =~ s/\$wikitoolname\b/$theWikiToolName/g;
  $theFormat =~ s/\$webtitle\b/$webTitle/g;
  $theFormat =~ s/\$web\b/$web/g;
  $theFormat =~ s/\$title\b/$topicTitle/g;
  $theFormat =~ s/\$topic\b/$topic/g;
  $theFormat =~ s/<nop>//g;
  $theFormat =~ s/<\/?noautolink>//g;

  return Foswiki::Func::decodeFormatTokens($theFormat);
}

1;
