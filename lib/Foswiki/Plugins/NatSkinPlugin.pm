###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2019 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();
use Foswiki::Plugins::NatSkinPlugin::WebComponent ();

our $START = '(?:^|(?<=[\w\b\s]))';
our $STOP = '(?:$|(?=[\w\b\s\,\.\;\:\!\?\)\(]))';
our $doneInjectRevinfo = 0;
our $donePrintOptions = 0;

###############################################################################
our $VERSION = '6.00';
our $RELEASE = '12 Feb 2019';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Support plugin for <nop>NatSkin';

###############################################################################
sub initPlugin {

  #print STDERR "### Perl Version $]\n";

  # theme engine macros
  Foswiki::Func::registerTagHandler(
    'SKINSTATE',
    sub {
      return getThemeEngine()->renderSkinState(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNSTYLES',
    sub {
      return getThemeEngine()->renderStyles(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNVARIATIONS',
    sub {
      return getThemeEngine()->renderVariations(@_);
    }
  );

  # REVISIONS, MAXREV, CURREV replacements
  Foswiki::Func::registerTagHandler(
    'PREVREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return Foswiki::Plugins::NatSkinPlugin::Utils::getPrevRevision($web, $topic, 1);
    }
  );

  Foswiki::Func::registerTagHandler(
    'CURREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision($web, $topic);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATMAXREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision($web, $topic);
    }
  );

  # skin macros
  Foswiki::Func::registerTagHandler(
    'USERACTIONS',
    sub {
      return getUserActions()->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATWEBLOGO',
    sub {
      return return getWebLogo()->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATSTYLEURL',
    sub {
      return getThemeEngine()->getStyleUrl();
    }
  );

  Foswiki::Func::registerTagHandler(
    'HTMLTITLE',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
      return Foswiki::Plugins::NatSkinPlugin::HtmlTitle::render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'IFSUBSCRIBED',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::render(@_);
    }
  );

  Foswiki::Func::registerRESTHandler(
    'subscribe',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::restSubscribe(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );
  Foswiki::Func::registerRESTHandler(
    'unsubscribe',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::restSubscribe(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerTagHandler(
    'WEBCOMPONENT',
    sub {
      return Foswiki::Plugins::NatSkinPlugin::WebComponent::render(@_);
    }
  );

  init();

  return 1;
}

###############################################################################
sub finishPlugin {

  my $session = $Foswiki::Plugins::SESSION;

  if (exists $session->{_NatSkin}) {
    foreach my $component (values %{$session->{_NatSkin}}) {
      $component->finish();
    }
  }

  undef $session->{_NatSkin};
}

###############################################################################
sub init {

  $doneInjectRevinfo = 0;
  $donePrintOptions = 0;
  getThemeEngine()->init();

  # setting default topictitle
  my $topicTitleField = Foswiki::Func::getPreferencesValue("TOPICTITLE_FIELD");
  Foswiki::Func::setPreferencesValue("TOPICTITLE_FIELD", "TopicTitle")
    unless defined $topicTitleField;

  Foswiki::Plugins::NatSkinPlugin::Utils::init();
  Foswiki::Plugins::NatSkinPlugin::WebComponent::init();
}

###############################################################################
sub getThemeEngine {

  my $session = $Foswiki::Plugins::SESSION;

  unless (defined $session->{_NatSkin}{ThemeEngine}) {
    require Foswiki::Plugins::NatSkinPlugin::ThemeEngine;
    $session->{_NatSkin}{ThemeEngine} = Foswiki::Plugins::NatSkinPlugin::ThemeEngine->new();
  }

  return $session->{_NatSkin}{ThemeEngine};
}

###############################################################################
sub getUserActions {
  my $session = $Foswiki::Plugins::SESSION;

  unless (defined $session->{_NatSkin}{UserActions}) {
    require Foswiki::Plugins::NatSkinPlugin::UserActions;
    $session->{_NatSkin}{UserActions} = Foswiki::Plugins::NatSkinPlugin::UserActions->new();
  }

  return $session->{_NatSkin}{UserActions};
}

###############################################################################
sub getWebLogo {
  my $session = $Foswiki::Plugins::SESSION;

  unless (defined $session->{_NatSkin}{WebLogo}) {
    require Foswiki::Plugins::NatSkinPlugin::WebLogo;
    $session->{_NatSkin}{WebLogo} = Foswiki::Plugins::NatSkinPlugin::WebLogo->new();
  }

  return $session->{_NatSkin}{WebLogo};
}

###############################################################################
sub endRenderingHandler {

  if ($Foswiki::cfg{NatSkin}{DetectExternalLinks}) {
    require Foswiki::Plugins::NatSkinPlugin::ExternalLink;
    $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.Foswiki::Plugins::NatSkinPlugin::ExternalLink::render($1,$2)/geoi;
  }

  if ($Foswiki::cfg{NatSkin}{FixTypograpghy}) {
    $_[0] =~ s/$START``$STOP/&#8220;/g;
    $_[0] =~ s/$START''$STOP/&#8221;/g;
    $_[0] =~ s/$START,,$STOP/&#8222;/g;
    $_[0] =~ s/$START\(c\)$STOP/&#169;/g;
    $_[0] =~ s/$START\(r\)$STOP/&#174;/g;
    $_[0] =~ s/$START\(tm\)$STOP/&#8482;/g;
    $_[0] =~ s/$START\.\.\.$STOP/&#8230;/g;
    $_[0] =~ s/$START\->$STOP/&#8594;/g;
    $_[0] =~ s/$START<\-$STOP/&#8592;/g;
    $_[0] =~ s/\-&gt;/&#8594;/g;
    $_[0] =~ s/&lt;\-/&#8592;/g;
  }

  # print options
  unless ($donePrintOptions) {
    $donePrintOptions = 1;
    my $request = Foswiki::Func::getCgiQuery();
    my $contenttype = $request->param("contenttype") || 'text/html';
    if ($contenttype eq "application/pdf") {
      my $paperSize = $request->param("pdfpagesize");
      my $orientation = $request->param("pdforientation");

      my $watermarkText = $request->param("pdfwatermark") || '';
      $watermarkText =~ s/\"/\\"/g;

      my $watermarkDom = "";
      if ($watermarkText && !Foswiki::Func::getContext()->{GenPDFPrincePluginEnabled}) {
        $watermarkDom = "<div class='natWatermark'>$watermarkText</div>";
      }

      my $styleText = "";
      my $pageSetup = "";

      if ($paperSize && $orientation) {
        $pageSetup = "size: $paperSize $orientation;";
      }

      $styleText = <<HERE;
<style type="text/css" media="print">
\@page {
  \@prince-overlay {
     color: rgba(0,0,0,0.2);
     content: "$watermarkText";
     line-height:1.1;
     text-align: center;
     top:50%;
     left:50%;
     width:100%;
     transform: rotate(-45deg);
     font-size:5em;
     font-weight:bold;
     text-transform:uppercase;
  }
  $pageSetup
}
</style>
HERE

      Foswiki::Func::addToZone("body", "NATSKIN::PRINTOPTIONS", <<HERE);
$styleText$watermarkDom
HERE
    }
  }

}

###############################################################################
sub completePageHandler {
  #my $text = $_[0];

  unless ($doneInjectRevinfo) {
    my $flag = Foswiki::Func::isTrue(Foswiki::Func::getPreferencesValue("DISPLAYREVISIONINFO"), 1);
    if ($flag && $_[0] =~ s/(<h1[^>]*>.*<\/h1>)/$1.&_insertRevInfo()/e) {
      $doneInjectRevinfo = 1;
    }
  }
}

sub _insertRevInfo {

  my $session = $Foswiki::Plugins::SESSION;
  my $web = $session->{webName};
  my $topic = $session->{topicName};
  
  my $text = Foswiki::Func::expandTemplate("revinfo");
  $text = Foswiki::Func::expandCommonVariables($text, $topic, $web);
  $text = Foswiki::Func::renderText($text, $web, $topic);
  $text =~ s/<!--[^\[<].*?-->//g;
  return $text;
}

1;

