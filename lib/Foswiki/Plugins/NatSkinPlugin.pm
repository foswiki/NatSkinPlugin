###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2012 MichaelDaum http://michaeldaumconsulting.com
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

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();
use Foswiki::Plugins::NatSkinPlugin::WebComponent ();

###############################################################################
our $baseWeb;
our $baseTopic;

our $VERSION = '$Rev$';
our $RELEASE = '4.00rc2';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Theming engine for NatSkin';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # theme engine macros
  Foswiki::Func::registerTagHandler('SKINSTATE', sub {
    return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderSkinState(@_);
  });

  Foswiki::Func::registerTagHandler('KNOWNSTYLES', sub {
    return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderStyles(@_);
  });

  Foswiki::Func::registerTagHandler('KNOWNVARIATIONS', sub {
    return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->renderVariations(@_);
  });

  # REVISIONS, MAXREV, CURREV replacements
  Foswiki::Func::registerTagHandler('PREVREV', sub {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getPrevRevision($baseWeb, $baseTopic, 1);
  });

  Foswiki::Func::registerTagHandler('CURREV', sub {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision($baseWeb, $baseTopic);
  });

  Foswiki::Func::registerTagHandler('NATMAXREV', sub {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision($baseWeb, $baseTopic);
  });

  Foswiki::Func::registerTagHandler('NATREVISIONS', sub {
    require Foswiki::Plugins::NatSkinPlugin::Revisions;
    return Foswiki::Plugins::NatSkinPlugin::Revisions::render(@_);
  });

  # skin macros
  Foswiki::Func::registerTagHandler('USERACTIONS', sub {
    require Foswiki::Plugins::NatSkinPlugin::UserActions;
    return Foswiki::Plugins::NatSkinPlugin::UserActions::render(@_);
  });

  Foswiki::Func::registerTagHandler('NATWEBLOGO', sub {
    require Foswiki::Plugins::NatSkinPlugin::WebLogo;
    return Foswiki::Plugins::NatSkinPlugin::WebLogo::render(@_);
  });

  Foswiki::Func::registerTagHandler('NATSTYLEURL', sub {
    return Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine()->getStyleUrl();
  });

  Foswiki::Func::registerTagHandler('HTMLTITLE', sub {
    require Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
    return Foswiki::Plugins::NatSkinPlugin::HtmlTitle::render(@_);;
  });

  Foswiki::Func::registerTagHandler('CONTENTTYPE', sub {
    require Foswiki::Plugins::NatSkinPlugin::ContentType;
    return Foswiki::Plugins::NatSkinPlugin::ContentType::render(@_);;
  });

  Foswiki::Func::registerTagHandler('WEBCOMPONENT', sub {
    return Foswiki::Plugins::NatSkinPlugin::WebComponent::render(@_);
  });

  # init modules
  Foswiki::Plugins::NatSkinPlugin::ThemeEngine::init();
  Foswiki::Plugins::NatSkinPlugin::Utils::init();
  Foswiki::Plugins::NatSkinPlugin::WebComponent::init();

  return 1;
}

###############################################################################
sub completePageHandler {

  return if defined $Foswiki::cfg{NatSkin}{CleanUpHTML} && !$Foswiki::cfg{NatSkin}{CleanUpHTML};

  $_[0] =~ s/<!--.*?-->//g;
  $_[0] =~ s/^\s*$//gms;
  $_[0] =~ s/(<\/html>).*?$/$1/gs;
  $_[0] =~ s/<p><\/p>(?:\s*<p><\/p>)*/\n<p><\/p>\n/gs;

  # clean up %{<verbatim>}% ...%{</verbatim>}%
  $_[0] =~ s/\%{(<pre[^>]*>)}&#37;\s*/$1/g;
  $_[0] =~ s/\s*&#37;{(<\/pre>)}\%/$1/g; 

  # remove superfluous type attributes
  $_[0] =~ s/<script +type=["']text\/javascript["']/<script/g;
  $_[0] =~ s/<style +type=["']text\/css["']/<style/g;

  # rewrite link
  $_[0] =~ s/<link (.*?rel=["']stylesheet["'].*?)\/>/_processLinkStyle($1)/ge;

}

sub _processLinkStyle {
  my $args = shift;
  $args =~ s/type=["'].*?["']//g;
  return "<link $args/>";
}

###############################################################################
sub preRenderingHandler {

  # better cite markup
  $_[0] =~ s/[\n\r](>.*?)([\n\r][^>])/handleCite($1).$2/ges;
}

sub handleCite {
  my $block = shift;

  $block =~ s/^>/<span class='foswikiCiteChar'>&gt;<\/span>/gm;
  $block =~ s/\n/<br \/>\n/g;

  my $class = ($block =~ /<br \/>/)?'foswikiBlockCite':'foswikiCite';

  return "<div class='$class'>".$block."</div>";
}

###############################################################################
sub postRenderingHandler { 
  
  # detect external links
  return unless $Foswiki::cfg{NatSkin}{DetectExternalLinks};

  require Foswiki::Plugins::NatSkinPlugin::ExternalLink;

  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.Foswiki::Plugins::NatSkinPlugin::ExternalLink::render($1,$2)/geoi;
}

1;

