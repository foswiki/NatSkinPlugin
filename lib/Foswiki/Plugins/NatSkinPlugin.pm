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

package Foswiki::Plugins::NatSkinPlugin;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin

base class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Contrib::MailerContrib ();
use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Plugins::NatSkinPlugin::Utils qw(getPrevRevision getCurRevision getMaxRevision);

our $VERSION = '7.10';
our $RELEASE = '%$RELEASE%';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Support plugin for <nop>NatSkin';
our $LICENSECODE = '%$LICENSECODE%';

our $START = qr/^|(?<=[\s\(])/m;
our $STOP  = qr/$|(?=[\w\s,.;:!\?\)])/m;

our $doneInjectRevinfo = 0;
our $donePrintOptions = 0;
our %modules = ();

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {
  my ($topic, $web) = @_;

  # flag topic context
  my $context = Foswiki::Func::getContext();
  $context->{$web} = 1;
  $context->{$topic} = 1;

  #print STDERR "### Perl Version $]\n";

  # theme engine macros
  Foswiki::Func::registerTagHandler(
    'SKINSTATE',
    sub {
      return getModule("ThemeEngine", shift)->renderSkinState(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNSTYLES',
    sub {
      return getModule("ThemeEngine", shift)->renderStyles(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNVARIATIONS',
    sub {
      return getModule("ThemeEngine", shift)->renderVariations(@_);
    }
  );

  # REVISIONS, MAXREV, CURREV replacements
  Foswiki::Func::registerTagHandler(
    'PREVREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return getPrevRevision($web, $topic, 1);
    }
  );

  Foswiki::Func::registerTagHandler(
    'CURREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return getCurRevision($web, $topic);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATMAXREV',
    sub {
      my ($session, $params, $topic, $web) = @_;
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $session->{webName}, $params->{topic} || $session->{topicName});
      return getMaxRevision($web, $topic);
    }
  );

  # skin macros
  Foswiki::Func::registerTagHandler(
    'USERACTIONS',
    sub {
      return getModule("UserActions", shift)->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATWEBLOGO',
    sub {
      return getModule("WebLogo", shift)->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'HTMLTITLE',
    sub {
      return getModule("HtmlTitle", shift)->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'IFSUBSCRIBED',
    sub {
      return getModule("Subscribe", shift)->render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'WEBCOMPONENT',
    sub {
      return getModule("WebComponent", shift)->render(@_);
    }
  );

  # message boxes 
  Foswiki::Func::registerTagHandler(
    'DEPRECATED',
    sub {
      my ($session, $params, $topic, $web) = @_;
      Foswiki::Func::addToZone("body", "flashnote", <<HERE);
<div class='foswikiHidden foswikiFlashNote'>%MAKETEXT{"[[[_1]]] is deprecated. Please fix your application." args="$web.$topic"}%</div>
HERE
      return "";
    }
  );

  Foswiki::Func::registerTagHandler('MESSAGEBOX', 
    sub {
      return getModule("MessageBox", shift)->render(@_);
    }
  );

  # stats macros
  Foswiki::Func::registerTagHandler('CACHEHITS', \&renderCacheHits);

  # JSON-RPC handlers
  Foswiki::Contrib::JsonRpcContrib::registerMethod("NatSkinPlugin", "subscribe", sub {
    return getModule("Subscribe", shift)->jsonRpcSubscribe(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("NatSkinPlugin", "unsubscribe", sub {
    return getModule("Subscribe", shift)->jsonRpcUnsubscribe(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("NatSkinPlugin", "restore", sub {
    return getModule("Restore", shift)->jsonRpcRestore(@_);
  });

  init();

  return 1;
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {

  # TODO: keep modules and just init them per request
  foreach my $key (keys %modules) {
    my $module = $modules{$key};
    $module->finish();
    undef $modules{$key};
  }

  %modules = ();
}

=begin TML

---++ init()

secondary initalization of this plugin. 

If the url parameter "unsubscribe" was found will it change the subscription
status in via Foswiki::Contrib::MailerContrib accordingly.

=cut

sub init {

  $doneInjectRevinfo = 0;
  $donePrintOptions = 0;

  my $session = $Foswiki::Plugins::SESSION;

  getModule("ThemeEngine", $session)->init();

  # unsubscribe url param
  my $request = Foswiki::Func::getRequestObject();
  my $sub = $request->param("unsubscribe");
  if (defined $sub) {
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    my $user = Foswiki::Func::getWikiName();

    if (Foswiki::Func::topicExists($web, $topic) && $user ne $Foswiki::cfg{DefaultUserWikiName}) {

      ($web, $sub) = Foswiki::Func::normalizeWebTopicName($web, $sub) if $sub ne '*';

      Foswiki::Contrib::MailerContrib::changeSubscription($web, $user, $sub, "-");
      my $note;
      if ($sub eq '*') {
        $note = $session->i18n->maketext('You have been unsubscribed from [_1].', $web);
      } else {
        $note = $session->i18n->maketext('You have been unsubscribed from [_1] in [_2].', $sub, $web);
      }
      Foswiki::Func::setPreferencesValue("FLASHNOTE", $note);
    }
  }
}

=begin TML

---++ getModule($name, $session) -> $impl

get a named singleton module of NatSkin

=cut

sub getModule {
  my $name = shift;
  my $session = shift;

  $session ||= $Foswiki::Plugins::SESSION;

  return unless defined $name;
  unless (defined $modules{$name}) {
    my $impl = "Foswiki::Plugins::NatSkinPlugin::$name";
    eval "require $impl";
    if ($@) {
      print STDERR "ERROR: $@\n";
      return;
    }
    my $module = $impl->new($session, @_);
    $modules{$name} = $module;
  }

  return $modules{$name};
}

=begin TML

---++ beforeCommonTagsHandler($text)

hooks into the named callback to process TMPL:DEF, TMPL:END and TMPL:INCLUDE
by wrapping them into a verbatim block. this helps visualiziong view templates as
you don't actually want to render their content visiting them in the browser. instead
they are only used when rendering the view of topics that have this template applied to.

=cut

sub beforeCommonTagsHandler {

  my $isTemplate = 0;

  # remove dummy comments
  $isTemplate = 1 if $_[0] =~ s/%\{\}%//g; 

  # improve rendering of view templates
  $isTemplate = 1 if $_[0] =~ s/(%TMPL:DEF\{"(.*?)"\}%.*?%TMPL:END%)/<verbatim class='tml tmplDef'>$1<\/verbatim>/gs;
  $isTemplate = 1 if $_[0] =~ s/(%TMPL:INCLUDE\{"(.*?)"\}%)/<verbatim class='tml tmplInclude'>$1<\/verbatim>/g;

  # only process if we detected TMPL: stuff
  if ($isTemplate) {
    # comments
    $_[0] =~ s/(\s*)(%\{.*?\}%)(\s*)/$1<verbatim class='tml tmplComment'>$2<\/verbatim>$3/gs;
    $_[0] =~ s/(#\{.*?\}#)/<verbatim class='tml tmplComment'>$1<\/verbatim>/gs;

    # backwards compatibility
    $_[0] =~ s/%\{<verbatim class=["']tml["']>\}%//g;
    $_[0] =~ s/%\{<\/verbatim>\}%//g;
  }
}

=begin TML

---++ endRenderingHandler($text)

some typographic fixes to optimize the html generated by the foswiki core

=cut

sub endRenderingHandler {

  if ($Foswiki::cfg{NatSkin}{DetectExternalLinks}) {
    $_[0] =~ s/<a\s+([^>]+?)\s*>(.+?)<\/a>/_externalLink($1, $2)/gei;
  }

  if ($Foswiki::cfg{NatSkin}{FixTypograpghy}) {
    $_[0] =~ s/$START``$STOP/&#8220;/g;
    $_[0] =~ s/\w''$STOP/&#8221;/g;
    $_[0] =~ s/$START,,$STOP/&#8222;/g;
    $_[0] =~ s/$START\(c\)$STOP/&#169;/g;
    $_[0] =~ s/$START\(r\)$STOP/&#174;/g;
    $_[0] =~ s/$START\(tm\)$STOP/&#8482;/g;
    $_[0] =~ s/$START\.\.\.$STOP/&#8230;/g; 
    $_[0] =~ s/$START\->$STOP/&#8594;/g;
    $_[0] =~ s/$START<\-$STOP/&#8592;/g;
    $_[0] =~ s/$START<\->$STOP/&#8596;/g;
    $_[0] =~ s/\-&gt;/&#8594;/g;
    $_[0] =~ s/&lt;\-/&#8592;/g;
  }

  # print options
  unless ($donePrintOptions) {
    $donePrintOptions = 1;
    my $request = Foswiki::Func::getRequestObject();
    my $contenttype = $request->param("contenttype") || 'text/html';
    if ($contenttype eq "application/pdf") {
      my $paperSize = $request->param("pdfpagesize") // "A4";
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
<style media="print">
\@page {
  $pageSetup
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
}
</style>
HERE

      Foswiki::Func::addToZone("body", "NATSKIN::PRINTOPTIONS", <<HERE);
$styleText$watermarkDom
HERE
    }
  }
}

=begin TML

---++ completePageHandler($text, $header)

optimize the html page on an html level. note that this replaces
similar features of PageOptimizerPlugin

=cut

sub completePageHandler {
  #my $text = $_[0];
  #my $header = $_[1];
  
  my $context = Foswiki::Func::getContext();
  #return unless $context->{view} || $context->{edit};
  return unless $_[1] =~ /Content-type: (text\/html|application\/pdf)/;

  unless ($doneInjectRevinfo) {
    my $flag = Foswiki::Func::isTrue(Foswiki::Func::getPreferencesValue("DISPLAYREVISIONINFO"), 1);
    if ($flag && $_[0] =~ s/(<h1 id="[^>]*>.*<\/h1>)/$1.&_insertRevInfo()/e) {
      $doneInjectRevinfo = 1;
    }
  }

  # hide link protocol from link text of phone links
  $_[0] =~ s/(<a href="(?:tel|sip|phone|skype):.+?">)(?:tel|sip|phone|skype):(.+?<\/a>)/$1$2/g;

  return if $context->{PageOptimizerPluginEnabled};

  # some cleanup from PageOptimizerPlugin
  use bytes;

  # remove non-macros and leftovers
  $_[0] =~ s/%(?:REVISIONS|REVTITLE|REVARG|QUERYPARAMSTRING)%//g;
  $_[0] =~ s/^%META:\w+{.*}%$//gm;

  # remove comments
  $_[0] =~ s/<!--[^\[<].*?-->//g;

  # clean up %{<verbatim>}% ...%{</verbatim>}% ... not required anymore
  $_[0] =~ s/\%\{(<pre[^>]*>)\}&#37;\s*/$1/g;
  $_[0] =~ s/\s*&#37;\{(<\/pre>)\}\%/$1/g;


  # make empty table cells really empty
  $_[0] =~ s/(<td[^>]*>)\s+(<\/td>)/$1$2/gs;

  # clean up non-html tags
  $_[0] =~ s/<\/?(?:nop|noautolink|sticky|literal)>//g;

  # remove type="text/css"
  $_[0] =~ s/(<style[^>]*?) type=["']text\/css["']/$1/g;

  # remove type="text/javascript"
  $_[0] =~ s/(<script[^>]*?) type=["']text\/javascript["']/$1/g;

  # remove anything after </html>
  $_[0] =~ s/(<\/html>).*$/$1/gs;

  # remove empty lines
  $_[0] =~ s/^\s*$//gms;

  no bytes;
}

sub renderCacheHits {
  my ($session, $params, $topic, $web) = @_;

  my $type = $params->{type} // 'prefs';
  my $result = '';
  my $format = '<span class="natCacheHits natCacheHits_$type">$count</span>';

  if ($type eq 'prefs') {
    $result = $format;
    my $impl = $Foswiki::cfg{Store}{PrefsBackend};
    my $count = $impl->cacheHits() if $impl->can("cacheHits");

    $result =~ s/\$type\b/$type/g;
    $result =~ s/\$count\b/$count/g;
  }

  return $result;
}

### static helper

sub _insertRevInfo {
  my $session = $Foswiki::Plugins::SESSION;
  my $web = $session->{webName};
  my $topic = $session->{topicName};
  
  my $text = Foswiki::Func::expandTemplate("revinfo");
  return "" if $text =~ /^\s*$/;

  $text = Foswiki::Func::expandCommonVariables($text, $topic, $web) if $text =~ /%/;
  $text = Foswiki::Func::renderText($text, $web, $topic);
  $text =~ s/<!--[^\[<].*?-->//g;
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;
  return $text;
}

sub _externalLink {
  my ($attrs, $text) = @_;

  my $urlHost = Foswiki::Func::getUrlHost();
  my $httpsUrlHost = $urlHost;
  $httpsUrlHost =~ s/^http:\/\//https:\/\//g;

  my %attrs = ();

  while ($attrs =~ /([^\s"']+)=(["'])(.*?)\2/gi) {
    $attrs{lc($1)} = $3;
  }

  my $url = delete $attrs{href} || '';

  my $isExternal = 0;
  $url =~ /^https?:\/\//i && ($isExternal = 1);    # only for this protocol
  $url =~ /^$urlHost/i && ($isExternal = 0);    # not for own host
  $url =~ /^$httpsUrlHost/i && ($isExternal = 0);    # not for own host
 
  if ($isExternal) {
    $attrs{class} = join(" ", "natExternalLink", sort split(/\s+/, $attrs{class}||''));
    $attrs{target} ||= $attrs{target} = '_blank';
    $attrs{rel} ||= $attrs{rel} = 'nofollow noopener noreferrer';
    return "<a ".($url?"href='$url' ":'').join(" ", map {"$_='$attrs{$_}'"} sort keys %attrs).">$text</a>";
  }

  # return original
  return "<a $attrs>$text</a>";
}

1;

