###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2009 MichaelDaum http://michaeldaumconsulting.com
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
use constant DEBUG => 0; # toggle me

###############################################################################
use vars qw(
  $baseWeb $baseTopic 
  $currentUser $VERSION $RELEASE 
  $useEmailObfuscator 
  $request %seenWebComponent
  $defaultSkin $defaultVariation 
  $defaultStyle $defaultStyleBorder $defaultStyleSideBar
  $defaultStyleTopicActions $defaultStyleButtons 
  %maxRevs
  $doneInitKnownStyles $doneInitSkinState
  $lastStylePath
  %knownThemes
  %knownStyles 
  %skinState 
  %emailCollection $nrEmails
  $STARTWW $ENDWW $emailRegex
  $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);


# from Render.pm
$STARTWW = qr/^|(?<=[\s\(])/m;
$ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;
$emailRegex = qr/([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+)\@([a-z0-9\-]+)([a-z0-9\-\.]*)/i;

$VERSION = '$Rev$';
$RELEASE = '3.94';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Theming engine for NatSkin';

# TODO generalize and reduce the ammount of variables 
$defaultSkin    = 'nat';
$defaultStyle   = 'jazzynote';
$defaultVariation = 'off';
$defaultStyleBorder = 'off';
$defaultStyleButtons = 'off';
$defaultStyleSideBar = 'left';
$defaultStyleTopicActions = 'on';


###############################################################################
sub writeDebug {
  return unless DEBUG;
  print STDERR "- NatSkinPlugin - " . $_[0] . "\n";
  #Foswiki::Func::writeDebug("- NatSkinPlugin - $_[0]");
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $currentUser) = @_;

  # register tags
  Foswiki::Func::registerTagHandler('GETSKINSTATE', \&renderGetSkinState);
  Foswiki::Func::registerTagHandler('WEBLINK', \&renderWebLink);
  Foswiki::Func::registerTagHandler('USERACTIONS', \&renderUserActions);
  Foswiki::Func::registerTagHandler('NATWEBLOGO', \&renderNatWebLogo);
  Foswiki::Func::registerTagHandler('NATSTYLEURL', \&renderNatStyleUrl);
  Foswiki::Func::registerTagHandler('KNOWNSTYLES', \&renderKnownStyles);
  Foswiki::Func::registerTagHandler('KNOWNVARIATIONS', \&renderKnownVariations);
  Foswiki::Func::registerTagHandler('WEBCOMPONENT', \&renderWebComponent);
  Foswiki::Func::registerTagHandler('USERREGISTRATION', \&renderUserRegistration);
  Foswiki::Func::registerTagHandler('HTMLTITLE', \&renderHtmlTitle);
  Foswiki::Func::registerTagHandler('CONTENTTYPE', \&renderContentType);

  # REVISIONS, MAXREV, CURREV only worked properly for the PatternSkin :/
  Foswiki::Func::registerTagHandler('NATREVISIONS', \&renderRevisions);
  Foswiki::Func::registerTagHandler('PREVREV', \&renderPrevRevision);
  Foswiki::Func::registerTagHandler('CURREV', \&renderCurRevision);
  Foswiki::Func::registerTagHandler('NATMAXREV', \&renderMaxRevision);

  # preference values
  $useEmailObfuscator = $Foswiki::cfg{NatSkin}{ObfuscateEmails};
  $doneInitSkinState = 0;

  %emailCollection = (); # collected email addrs
  $nrEmails = 0; # number of collected addrs
  %maxRevs = (); # cache for getMaxRevision()
  %seenWebComponent = (); # used to prevent deep recursion
  $request = Foswiki::Func::getCgiQuery();
  my $skin = Foswiki::Func::getSkin();

  if ($useEmailObfuscator) {
    my $isScripted = Foswiki::Func::getContext()->{'command_line'}?1:0;
    if ($isScripted || !$request) { # are we in cgi mode?
      $useEmailObfuscator = 0; # batch mode, i.e. mailnotification
      #writeDebug("no email obfuscation: batch mode");
    } else {
      # disable during register context
      my $theContentType = $request->param('contenttype');
      if ($skinState{'action'} =~ /^(register|mailnotif|resetpasswd)/ || 
	  $skin =~ /^(rss|atom)/ ||
	  $theContentType) {
	$useEmailObfuscator = 0;
      }
    }
  }
  #writeDebug("useEmailObfuscator=$useEmailObfuscator");

  my $doRefresh = $request->param('refresh') || ''; # refresh internal caches
  $doRefresh = ($doRefresh eq 'on')?1:0;
  if ($doRefresh) {
    $doneInitKnownStyles = 0;
    $lastStylePath = '';
  }

  # get skin state from session
  initKnownStyles();
  initSkinState();

  if ($skin =~ /\bnat\b/) {
    Foswiki::Func::setPreferencesValue('FOSWIKI_STYLE_URL', '%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseStyle.css');
    Foswiki::Func::setPreferencesValue('FOSWIKI_COLORS_URL', '%NATSTYLEURL%');

    Foswiki::Func::addToHEAD('NATSKIN::JS', <<'HERE', 'NATSKIN, NATSKIN::OPTS, JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::SUPERFISH');
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/foswikilib.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/natskin.js"></script>
HERE

    Foswiki::Func::addToHEAD('NATSKIN', "\n".getSkinStyle(), 'TABLEPLUGIN_default');
  }

  return 1;
}
###############################################################################
sub preRenderingHandler { 
  if ($useEmailObfuscator) {
    $_[0] =~ s/\[\[mailto\:($emailRegex(?:\s*,\s*$emailRegex)*)(?:\s+|\]\[)(.*?)\]\]/obfuscateEmailAddrs($1, $8)/ge;
    $_[0] =~ s/$STARTWW(?:mailto\:)?($emailRegex(?:\s*,\s*$emailRegex)*)$ENDWW/obfuscateEmailAddrs($1)/ge;
  }
}

###############################################################################
sub postRenderingHandler { 
  
  # detect external links
  if ($Foswiki::cfg{NatSkin}{DetectExternalLinks}) {
    $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.renderExternalLink($1,$2)/geoi;
    $_[0] =~ s/(<a\s+[^>]+ target="_blank" [^>]+) target="_top"/$1/go; # core adds target="_top" ... we kick it out again
  }

  # render email obfuscator
  if ($useEmailObfuscator && $nrEmails) {
    $useEmailObfuscator = 0;
    Foswiki::Func::addToHEAD('EMAIL_OBFUSCATOR', renderEmailObfuscator(), 'NATSKIN');
    $useEmailObfuscator = 1;
  }
}

###############################################################################
sub obfuscateEmailAddrs {
  my ($emailAddrs, $linkText) = @_;

  $linkText = '' unless $linkText;

  my @emailAddrs = split(/\s*,\s*/, $emailAddrs);
  #writeDebug("called obfuscateEmailAddrs([".join(", ", @emailAddrs)."], $linkText)");

  my $emailKey = '_wremoId'.$nrEmails;
  $nrEmails++;

  $emailCollection{$emailKey} = [\@emailAddrs, $linkText]; 
  my $text = "<span class='wremo' id='$emailKey'>$emailKey</span>";

  #writeDebug("result: $text");
  return $text;
}

###############################################################################
sub renderEmailObfuscator {

  #writeDebug("called renderEmailObfuscator()");

  my $text = "\n".
    '<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/obfuscator.js"></script>'."\n".
    '<script type="text/javascript">'."\n".
    "<!--\n".
    "var emoas = new Array();\n";

  foreach my $emailKey (sort keys %emailCollection) {
    my $emailAddrs = $emailCollection{$emailKey}->[0];
    my $linkText = $emailCollection{$emailKey}->[1];
    $text .= "emoas['$emailKey'] = ['$linkText', [";
    my @lines;
    foreach my $addr (@$emailAddrs) {
      next unless $addr =~ m/^$emailRegex$/;
      my $theAccount = $1;
      my $theSubDomain = $2;
      my $theTopDomain = $3 || '';
      push @lines, "['$theSubDomain','$theAccount','$theTopDomain']";
    }
    $text .= join(",", @lines)."]];\n";
  }
  $text .= "//-->\n</script>\n";
  return $text;
}


###############################################################################
# known styles are attachments found along the STYLEPATH. any *Style.css,
# *Variation.css etc files are collected hashed.
sub initKnownStyles {

  #writeDebug("called initKnownStyles");
  #writeDebug("stylePath=$stylePath, lastStylePath=$lastStylePath");

  my $systemWeb = $Foswiki::cfg{SystemWebName};
  my $stylePath = Foswiki::Func::getPreferencesValue('STYLEPATH') 
    || "$systemWeb.JazzyNoteTheme, $systemWeb.NatSkin";

  $stylePath =~ s/\%SYSTEMWEB\%/$systemWeb/go;
  $stylePath =~ s/\%TWIKIWEB\%/TWiki/go;

  $lastStylePath ||= '';

  # return cached known styles if we have the same stylePath
  # as last time
  return if $doneInitKnownStyles && $stylePath eq $lastStylePath;

  $doneInitKnownStyles = 1;
  $lastStylePath = $stylePath;
  %knownStyles = ();
  %knownThemes = ();

  my $pubDir = $Foswiki::cfg{PubDir};
  my $pubUrlPath = Foswiki::Func::getPubUrlPath();
  foreach my $styleWebTopic (split(/\s*,\s*/, $stylePath)) {
    my ($styleWeb, $styleTopic) =
      Foswiki::Func::normalizeWebTopicName($systemWeb, $styleWebTopic);

    $styleWebTopic = $styleWeb.'/'.$styleTopic;
    my $themeId = $styleWebTopic;
    my %themeRecord = (
      id=>$themeId,
      dir=> $pubDir.'/'.$styleWebTopic,
      path=> $pubUrlPath.'/'.$styleWebTopic,
      styles => undef,
      variations => undef,
      borders => undef,
      thins => undef,
    );

    if (opendir(DIR, $themeRecord{dir}))  {
      foreach my $fileName (readdir(DIR)) {
	if ($fileName =~ /((.*)Style\.css)$/) {
          my $id = lc($2);
          $knownStyles{$id} = $themeId;
          $themeRecord{styles}{$id} = $themeRecord{path}.'/'.$1;
	} elsif ($fileName =~ /((.*)Variation\.css)$/) {
          my $id = lc($2);
          $themeRecord{variations}{$id} = $themeRecord{path}.'/'.$1;
	} elsif ($fileName =~ /((.*)Border\.css)$/) {
          my $id = lc($2);
          $themeRecord{borders}{$id} = $themeRecord{path}.'/'.$1;
	} elsif ($fileName =~ /((.*)Buttons\.css)$/) {
          my $id = lc($2);
          $themeRecord{buttons}{$id} = $themeRecord{path}.'/'.$1;
	} elsif ($fileName =~ /((.*)Thin\.css)$/) {
          my $id = lc($2);
          $themeRecord{thins}{$id} = $themeRecord{path}.'/'.$1;
	}
      }
      closedir(DIR);

      # only add theme record if it has at least one style
      if ($themeRecord{styles}) {
        $knownThemes{$themeId} = \%themeRecord;
      }
    }
  }
}

###############################################################################
sub initSkinState {

  return 1 if $doneInitSkinState;

  $doneInitSkinState = 1;
  %skinState = ();

  #writeDebug("called initSkinState");

  my $theStyle;
  my $theStyleBorder;
  my $theStyleButtons;
  my $theStyleSideBar;
  my $theStyleTopicActions;
  my $theStyleVariation;
  my $theToggleSideBar;
  my $theRaw;
  my $theSwitchStyle;
  my $theSwitchVariation;

  my $doStickyStyle = 0;
  my $doStickyBorder = 0;
  my $doStickyButtons = 0;
  my $doStickySideBar = 0;
  my $doStickyTopicActions = 0;
  my $doStickyVariation = 0;
  my $found = 0;
  my $session = $Foswiki::Plugins::SESSION;

  # from request
  if ($request) {
    $theRaw = $request->param('raw');
    $theSwitchStyle = $request->param('switchstyle');
    $theSwitchVariation = $request->param('switchvariation');
    $theStyle = $request->param('style') || $request->param('skinstyle') || '';

    my $theReset = $request->param('resetstyle') || ''; # get back to site defaults
    $theReset = ($theReset eq 'on')?1:0;

    if ($theReset || $theStyle eq 'reset') {
      # clear the style cache
      $doneInitKnownStyles = 0; 
      $lastStylePath = '';
    }

    if ($theReset || $theStyle eq 'reset') {
      #writeDebug("clearing session values");
      
      $theStyle = '';
      Foswiki::Func::clearSessionValue('SKINSTYLE');
      Foswiki::Func::clearSessionValue('STYLEBORDER');
      Foswiki::Func::clearSessionValue('STYLEBUTTONS');
      Foswiki::Func::clearSessionValue('STYLESIDEBAR');
      Foswiki::Func::clearSessionValue('STYLEVARIATION');
      my $redirectUrl = $session->getScriptUrl(0, 'view', $baseWeb, $baseTopic);
      Foswiki::Func::redirectCgiQuery($request, $redirectUrl); 
	# we need to force a new request because the session value preferences
	# are still loaded in the preferences cache; only clearing them in
	# the session object is not enough right now but will be during the next
	# request; so we redirect to the current url
      return 0;
    } else {
      $theStyleBorder = $request->param('styleborder'); 
      $theStyleButtons = $request->param('stylebuttons'); 
      $theStyleSideBar = $request->param('stylesidebar');
      $theStyleTopicActions = $request->param('styletopicactions');
      $theStyleVariation = $request->param('stylevariation');
      $theToggleSideBar = $request->param('togglesidebar');
    }

    #writeDebug("urlparam style=$theStyle") if $theStyle;
    #writeDebug("urlparam styleborder=$theStyleBorder") if $theStyleBorder;
    #writeDebug("urlparam stylebuttons=$theStyleButtons") if $theStyleButtons;
    #writeDebug("urlparam stylesidebar=$theStyleSideBar") if $theStyleSideBar;
    #writeDebug("urlparam stylevariation=$theStyleVariation") if $theStyleVariation;
    #writeDebug("urlparam togglesidebar=$theToggleSideBar") if $theToggleSideBar;
    #writeDebug("urlparam switchvariation=$theSwitchVariation") if $theSwitchVariation;
  }

  # handle style
  my $prefStyle = 
    Foswiki::Func::getSessionValue('SKINSTYLE') || 
    Foswiki::Func::getPreferencesValue('SKINSTYLE') || 
    $defaultStyle;
  $prefStyle =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyle) {
    $theStyle =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyStyle = 1 if lc($theStyle) ne lc($prefStyle);
  } else {
    $theStyle = $prefStyle;
  }
  if ($theStyle =~ /^(off|none)$/o) {
    $theStyle = 'off';
  } else {
    $found = 0;
    foreach my $style (keys %knownStyles) {
      if ($style eq $theStyle || lc($style) eq lc($theStyle)) {
	$found = 1;
	$theStyle = $style;
	last;
      }
    }
    $theStyle = $defaultStyle unless $found;
  }
  $theStyle = $defaultStyle unless $knownStyles{$theStyle};

  # cycle styles
  if ($theSwitchStyle) {
    $theSwitchStyle = lc($theSwitchStyle);
    $doStickyStyle = 1;
    my $state = 0;
    my $firstStyle;
    my @knownStyles;
    if ($theSwitchStyle eq 'next') {
      @knownStyles = sort {$a cmp $b} keys %knownStyles #next
    } else {
      @knownStyles = sort {$b cmp $a} keys %knownStyles #prev
    }
    foreach my $style (@knownStyles) {
      $firstStyle = $style unless $firstStyle;
      if ($theStyle eq $style) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'style'} = $style;
	$state = 2;
	last;
      }
    }
    $skinState{'style'} = $firstStyle if $state == 1;
  }

  $skinState{'style'} = $theStyle; ## SMELL: seems to override cycle styles
  my $themeRecord = getThemeRecord($theStyle);
  #writeDebug("theStyle=$theStyle");

  # handle border
  my $prefStyleBorder = 
    Foswiki::Func::getSessionValue('STYLEBORDER') || 
    Foswiki::Func::getPreferencesValue('STYLEBORDER') ||
    $defaultStyleBorder;

  $prefStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleBorder) {
    $theStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyBorder = 1 if $theStyleBorder ne $prefStyleBorder;
  } else {
    $theStyleBorder = $prefStyleBorder;
  }
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder !~ /^(on|off|thin)$/;
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'on' && $themeRecord && !$themeRecord->{borders}{$theStyle};
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'thin' && $themeRecord && !$themeRecord->{thins}{$theStyle};
  $skinState{'border'} = $theStyleBorder;

  # handle buttons
  my $prefStyleButtons = 
    Foswiki::Func::getSessionValue('STYLEBUTTONS') ||
    Foswiki::Func::getPreferencesValue('STYLEBUTTONS') ||
    $defaultStyleButtons;
  $prefStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleButtons) {
    $theStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyButtons = 1 if $theStyleButtons ne $prefStyleButtons;
  } else {
    $theStyleButtons = $prefStyleButtons;
  }
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons !~ /^(on|off)$/;
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons eq 'on' && $themeRecord && !$themeRecord->{buttons}{$theStyle};
  $skinState{'buttons'} = $theStyleButtons;

  # handle sidebar 
  my $prefStyleSideBar = 
    Foswiki::Func::getSessionValue('STYLESIDEBAR') ||
    Foswiki::Func::getPreferencesValue('STYLESIDEBAR') ||
    $defaultStyleSideBar;
  $prefStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleSideBar) {
    $theStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
    $doStickySideBar = 1 if $theStyleSideBar ne $prefStyleSideBar;
  } else {
    $theStyleSideBar = $prefStyleSideBar;
  }
  $theStyleSideBar = $defaultStyleSideBar
    if $theStyleSideBar !~ /^(left|right|both|off)$/;
  $skinState{'sidebar'} = $theStyleSideBar;
  $theToggleSideBar = undef
    if $theToggleSideBar && $theToggleSideBar !~ /^(left|right|both|off)$/;

  # handle variation 
  my $prefStyleVariation = 
    Foswiki::Func::getSessionValue('STYLEVARIATION') ||
    Foswiki::Func::getPreferencesValue('STYLEVARIATION') ||
    $defaultVariation;

  $prefStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleVariation) {
    $theStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyVariation = 1 if lc($theStyleVariation) ne lc($prefStyleVariation);
  } else {
    $theStyleVariation = $prefStyleVariation;
  }
  $found = 0;
  foreach my $variation (keys %{$themeRecord->{variations}}) {
    if ($variation eq $theStyleVariation || lc($variation) eq lc($theStyleVariation)) {
      $found = 1;
      $theStyleVariation = $variation;
      last;
    }
  }
  $theStyleVariation = $defaultVariation unless $found;
  $skinState{'variation'} = $theStyleVariation;

  # cycle styles
  if ($theSwitchVariation) {
    $theSwitchVariation = lc $theSwitchVariation;
    $doStickyVariation = 1;
    my $state = 0;
    my @knownVariations;
    if ($theSwitchVariation eq 'next') {
      @knownVariations = sort {$a cmp $b} keys %{$themeRecord->{variations}}; #next
    } else {
      @knownVariations = sort {$b cmp $a} keys %{$themeRecord->{variations}}; #prev
    }
    push @knownVariations, 'off';
    my $firstVari;
    foreach my $vari (@knownVariations) {
      $firstVari = $vari unless $firstVari;
      if ($theStyleVariation eq $vari) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'variation'} = $vari;
	$state = 2;
	last;
      }
    }
    $skinState{'variation'} = $firstVari if $state == 1;
  }

  # store sticky state into session
  Foswiki::Func::setSessionValue('SKINSTYLE', $skinState{'style'}) 
    if $doStickyStyle;
  Foswiki::Func::setSessionValue('STYLEBORDER', $skinState{'border'})
    if $doStickyBorder;
  Foswiki::Func::setSessionValue('STYLEBUTTONS', $skinState{'buttons'})
    if $doStickyButtons;
  Foswiki::Func::setSessionValue('STYLESIDEBAR', $skinState{'sidebar'})
    if $doStickySideBar;
  Foswiki::Func::setSessionValue('STYLEVARIATION', $skinState{'variation'})
    if $doStickyVariation;

  # misc
  $skinState{'action'} = getRequestAction();

  # switch on history context
  my $curRev = ($request)?$request->param('rev'):'';
  if ($curRev || $skinState{"action"} =~ /rdiff|compare/) {
    $skinState{"history"} = 1;
  } else {
    $skinState{"history"} = 0;
  }

  # temporary toggles
  $theToggleSideBar = 'off' if $skinState{'action'} =~ 
    /^(edit|genpdf|manage|changes|(.*search)|login|logon|oops)$/;

  # switch the sidebar off if we need to authenticate
  my $authScripts = $Foswiki::cfg{AuthScripts};
  if ($skinState{'action'} ne 'publish' && # SMELL to please PublishContrib
      $authScripts =~ /\b$skinState{'action'}\b/ &&
      !Foswiki::Func::getContext()->{authenticated}) {
      $theToggleSideBar = 'off';
  }

  $skinState{'sidebar'} = $theToggleSideBar 
    if $theToggleSideBar && $theToggleSideBar ne '';

  # set context
  my $context = Foswiki::Func::getContext();
  foreach my $key (keys %skinState) {
    my $val = $skinState{$key};
    next unless defined($val);
    my $var = lc('natskin_'.$key.'_'.$val);
    writeDebug("setting context $var");
    $context->{$var} = 1;
  }

  # prepend style to template search path

  my $skin = $request->param('skin') || 
    Foswiki::Func::getPreferencesValue( 'SKIN' ) || 'nat'; 
    # not using Foswiki::Func::getSkin() to prevent 
    # getting the cover as well

  if ($skin =~ /\bnat\b/) {
    my $prefix = lc($skinState{'style'}).'.nat';
    $skin = "$prefix,$skin" unless $skin =~ /\b$prefix\b/;
    
    if ($skinState{'variation'} ne 'off') {
      $prefix = lc($skinState{'variation'}.'.'.$skinState{'style'}).'.nat';
      $skin = "$prefix,$skin" unless $skin =~ /\b$prefix\b/;
    }

    # auto-add natedit
    $skin = "natedit,$skin" unless $skin =~ /\b(natedit)\b/;

    #writeDebug("setting skin to $skin");

    # store session prefs
    Foswiki::Func::setPreferencesValue('SKIN', $skin);
  }

  return 1;
}

###############################################################################
sub renderUserRegistration {
  my $systemWeb = $Foswiki::cfg{SystemWebName};

  my $userRegistrationTopic = 
    Foswiki::Func::getPreferencesValue('USERREGISTRATION');

  $userRegistrationTopic = "$systemWeb.UserRegistration" 
    unless defined $userRegistrationTopic;
  
  return $userRegistrationTopic;
}

###############################################################################
# SMELL: move this into the core
sub renderContentType {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $contentType = $request->param('contenttype');
  my $skin = Foswiki::Func::getSkin();
  my $raw = $request->param('raw') || '';

  unless ($contentType) {
    if ($skin =~ /\b(rss|atom|xml)/ ) {
      $contentType = 'text/xml';
    } elsif ($raw eq 'text' || $raw eq 'all') {
      $contentType = 'text/plain';
    } else {
      $contentType = 'text/html';
    }
  }

  return $contentType;
}

###############################################################################
sub renderHtmlTitle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theSep = $params->{separator} || ' - ';
  my $theWikiToolName = $params->{wikitoolname} || 'on';
  my $theSource = $params->{source} || '%TOPICTITLE%';

  if ($theWikiToolName eq 'on') {
    $theWikiToolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME") || 'Wiki';
    $theWikiToolName = $theSep.$theWikiToolName;
  } elsif ($theWikiToolName eq 'off') {
    $theWikiToolName = '';
  } else {
    $theWikiToolName = $theSep.$theWikiToolName;
  }

  my $htmlTitle = Foswiki::Func::getPreferencesValue("HTMLTITLE");
  if ($htmlTitle) {
    return $htmlTitle; # deliberately not appending the WikiToolName
  }

  $theWeb =~ s/^.*[\.\/]//g;

  # the source can be a preference variable or a WikiTag
  escapeParameter($theSource);
  $htmlTitle = Foswiki::Func::expandCommonVariables($theSource, $theTopic, $theWeb);
  if ($htmlTitle && $htmlTitle ne $theSource) {
    return $htmlTitle.$theSep.$theWeb.$theWikiToolName;
  }

  # fallback
  return $theTopic.$theSep.$theWeb.$theWikiToolName;
}


###############################################################################
sub renderIfSkinState {
  my ($session, $params) = @_;

  my $theStyle = $params->{_DEFAULT} || $params->{style};
  my $theThen = $params->{then};
  my $theElse = $params->{else};
  my $theBorder = $params->{border};
  my $theButtons = $params->{buttons};
  my $theVariation = $params->{variation};
  my $theSideBar = $params->{sidebar};
  my $theAction = $params->{action};
  my $theHistory = $params->{history};

  # SMELL do a ifSkinStateImpl
  if ((!defined($theStyle) || $skinState{'style'} =~ /$theStyle/i) &&
      (!defined($theVariation) || $skinState{'variation'} =~ /$theVariation/i) &&
      (!defined($theBorder) || $skinState{'border'} =~ /$theBorder/) &&
      (!defined($theButtons) || $skinState{'buttons'} =~ /$theButtons/) &&
      (!defined($theSideBar) || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!defined($theAction) || $skinState{'action'} =~ /$theAction/) &&
      (!defined($theHistory) || $skinState{'history'} eq $theHistory)) {

    escapeParameter($theThen);
    if ($theThen) {
      $theThen = Foswiki::Func::expandCommonVariables($theThen, $baseTopic, $baseWeb);
      #writeDebug("match");
      return $theThen;
    }
  } else {
    escapeParameter($theElse);
    if ($theElse) {
      $theElse = Foswiki::Func::expandCommonVariables($theElse, $baseTopic, $baseWeb);
      #writeDebug("NO match");
      return $theElse;
    }
  }

  return '';
}

###############################################################################
sub renderKnownStyles {
  return join(', ', sort {$a cmp $b} keys %knownStyles);
}

###############################################################################
sub renderKnownVariations {
  my ($session, $params) = @_;

  my $theStyle = $params->{style} || '.*';
  my $theFormat = $params->{format} || '$style = $variation';
  my $theSep = $params->{separator} || ', ';
  my $theVarSep = $params->{varseparator} || ', ';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  my @result;
  foreach my $style (keys %knownStyles) {
    next if $theStyle && $style !~ /^($theStyle)$/i;
    my $themeRecord = getThemeRecord($style);
    next unless $themeRecord;
    my $vars = join($theVarSep, keys %{$themeRecord->{variations}});
    next unless $vars;
    my $line = $theHeader.$theFormat.$theFooter;
    $line =~ s/\$variation\b/$vars/g;
    $line =~ s/\$style\b/$style/g;
    push @result, $line;
  }
  return '' unless @result;
  return join($theSep, @result);
}

###############################################################################
sub renderGetSkinState {

  my ($session, $params) = @_;

  my $theFormat = $params->{_DEFAULT} || 
    '$style, $variation, $sidebar, $border, $buttons';
  my $theLowerCase = $params->{lowercase} || 0;
  $theLowerCase = ($theLowerCase eq 'on')?1:0;

  $theFormat =~ s/\$style/$skinState{'style'}/g;
  $theFormat =~ s/\$variation/$skinState{'variation'}/g;
  $theFormat =~ s/\$border/$skinState{'border'}/g;
  $theFormat =~ s/\$buttons/$skinState{'buttons'}/g;
  $theFormat =~ s/\$sidebar/$skinState{'sidebar'}/g;
  $theFormat = lc($theFormat);

  return $theFormat;
}

###############################################################################
sub getThemeRecord {
  my $theStyle = shift;

  $theStyle ||= $defaultStyle;
  
  $theStyle = $defaultStyle unless $knownStyles{$theStyle};
  return unless $knownStyles{$theStyle};

  $theStyle = $defaultStyle unless $knownThemes{$knownStyles{$theStyle}};
  return unless $knownThemes{$knownStyles{$theStyle}};

  return $knownThemes{$knownStyles{$theStyle}};
}

###############################################################################
sub getSkinStyle {

  my $theStyle;
  $theStyle = $skinState{'style'} || 'off';

  return '' if $theStyle eq 'off';

  my $theVariation;
  $theVariation = $skinState{'variation'} unless $skinState{'variation'} =~ /^(off|none)$/;

  # SMELL: why not use <link rel="stylesheet" href="..." type="text/css" media="all" />
  my $text = '';

  $theStyle = lc $theStyle;
  $theVariation = lc $theVariation;

  my $themeRecord = getThemeRecord($theStyle);
  return '' unless $themeRecord;

  #writeDebug("theStyle=$theStyle");
  #writeDebug("knownStyle=".join(',', sort keys %knownStyles));

  $text = <<"HERE";
<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/NatSkin/print.css\" type=\"text/css\" media=\"print\" />
<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseStyle.css\" type=\"text/css\" media=\"all\" />
<link rel=\"stylesheet\" href=\"$themeRecord->{styles}{$theStyle}\" type=\"text/css\" media=\"all\" />
HERE

  if ($skinState{'border'} eq 'on' && $themeRecord->{borders}{$theStyle}) {
    $text .= <<"HERE";
<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseBorder.css\" type=\"text/css\" media=\"all\" />
<link rel=\"stylesheet\" href=\"$themeRecord->{borders}{$theStyle}\" type=\"text/css\" media=\"all\" />
HERE
  } elsif ($skinState{'border'} eq 'thin' && $themeRecord->{thins}{$theStyle}) {
    $text .= <<"HERE";
<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseThin.css\" type=\"text/css\" media=\"all\" />
<link rel=\"stylesheet\" href=\"$themeRecord->{thins}{$theStyle}\" type=\"text/css\" media=\"all\" />
HERE
  }

  if ($skinState{'buttons'} eq 'on' && $themeRecord->{buttons}{$theStyle}) {
    $text .= <<"HERE";
<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseButtons.css\" type=\"text/css\" media=\"all\" />
<link rel=\"stylesheet\" href=\"$themeRecord->{buttons}{$theStyle}\" type=\"text/css\" media=\"all\" />
HERE
  }

  if ($theVariation && $themeRecord->{variations}{$theVariation}) {
    $text .= <<"HERE";
<link rel=\"stylesheet\" href=\"$themeRecord->{variations}{$theVariation}\" type=\"text/css\" media=\"all\" />
HERE
  }

  return $text;
}


###############################################################################
# renderUserActions: render the USERACTIONS variable:
# display advanced topic actions for non-guests
sub renderUserActions {
  my ($session, $params) = @_;

  my $sepString = $params->{sep} || $params->{separator} || '<span class="natSep"> | </span>';

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $text = $params->{_DEFAULT} || $params->{format};
  unless ($text) {
    $text = '<div class="natTopicActions">$edit$sep$attach$sep$new$sep$raw$sep$delete$sep$history$sep';
    $text .= '$subscribe$sep$' if Foswiki::Func::getContext()->{SubscribePluginEnabled};
    $text .= 'print$sep$more</div>';
  }

  unless (Foswiki::Func::getContext()->{authenticated}) {
    my $guestText = $params->{guest};
    $text = $guestText if defined $guestText;
  }

  if ($skinState{"history"}) {
    my $historyText = $params->{history};
    $text = $historyText if defined $historyText;
  }

  return '' unless $text;

  my $newString = '';
  my $editString = '';
  my $editFormString = '';
  my $editTextString = '';
  my $attachString = '';
  my $deleteString = '';
  my $moveString = '';
  my $rawString = '';
  my $closeString = '';
  my $historyString = '';
  my $diffString = '';
  my $moreString = '';
  my $printString = '';
  my $pdfString = '';
  my $loginString = '';
  my $logoutString = '';
  my $registerString = '';
  my $accountString = '';
  my $usersString = '';
  my $helpString = '';
  my $firstString = '';
  my $lastString = '';
  my $nextString = '';
  my $prevString = '';
  my $subscribeString = '';

  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'new, edit, attach, move, delete, diff, more, raw' 
    unless defined $restrictedActions;
  my %isRestrictedAction = map {$_ => 1} split(/\s*,\s*/, $restrictedActions);

  $isRestrictedAction{'subscribe'} = 1
    if Foswiki::Func::isGuest();

  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE',$currentUser,undef,$baseTopic, $baseWeb);
  %isRestrictedAction = () if $gotAccess;

  #writeDebug("restrictedActions=".join(',', sort keys %isRestrictedAction));

  # get change strings (edit, attach, move)
  my $maxRev = getMaxRevision($baseWeb, $baseTopic);
  my $curRev = getCurRevision($baseWeb, $baseTopic);
  $curRev ||= ($maxRev || 1);

  my $nrRev;
  if ($request) {
    my $rev1 = $request->param('rev1') || 1;
    my $rev2 = $request->param('rev2') || 1;
    $nrRev = abs($rev1 - $rev2);
  }
  $nrRev = 1 unless $nrRev;
  my $prevRev = $curRev - $nrRev;
  my $nextRev = $curRev + $nrRev;

  #writeDebug("curRev=$curRev, prevRev=$prevRev, nextRev=$nextRev, maxRev=$maxRev");

  my $isCompare = $skinState{'action'} eq 'compare';
  my $isRaw = ($request)?$request->param('raw'):'';
  my $renderMode = ($request)?$request->param('render'):'';
  $renderMode = $isCompare?'interweave':'sequential' unless defined $renderMode;
  my $diffCommand = $isCompare?'compare':'rdiff';

  # new
  if ($text =~ /\$new\b/) {
    if ($isRestrictedAction{'new'}) {
      $newString = Foswiki::Func::expandTemplate('NEW_ACTION_RESTRICTED');
    } else {
      my $topicFactory = Foswiki::Func::getPreferencesValue('TOPICFACTORY') || 'WebCreateNewTopic';
      my $url = $session->getScriptUrl(0, 'view', $baseWeb, $baseTopic, 
        'template' => $topicFactory, 
      );
      $newString = Foswiki::Func::expandTemplate('NEW_ACTION');
      $newString =~ s/%\$url%/$url/g;
    }
  }
    
  # edit
  if ($text =~ /\$edit\b/) {
    if ($isRestrictedAction{'edit'}) {
      if ($skinState{"history"}) {
        $editString = Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED');
      } else {
        $editString = Foswiki::Func::expandTemplate('EDIT_ACTION_RESTRICTED');
      }
    } else {
      if ($skinState{"history"}) {
        my $url = $session->getScriptUrl(0, "edit", $baseWeb, $baseTopic, 
          't'=>time(),
          'rev'=>$prevRev
        );
        $editString = Foswiki::Func::expandTemplate('RESTORE_ACTION');
        $editString =~ s/%\$url%/$url/g;
      } else {
        my $whiteBoard = Foswiki::Func::getPreferencesValue('WHITEBOARD');
        my $url = $session->getScriptUrl(0, "edit", $baseWeb, $baseTopic,
          't'=>time(),
        );
        $url .= '&action=form' unless isTrue($whiteBoard, 1);
        $editString = Foswiki::Func::expandTemplate('EDIT_ACTION');
        $editString =~ s/%\$url%/$url/g;
      }
    }
  }

  # edit form
  if ($text =~ /\$editform\b/) {
    if ($isRestrictedAction{'edit'}) {
      $editFormString = Foswiki::Func::expandTemplate('EDITFORM_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "edit", $baseWeb, $baseTopic,
        't'=> time(),
        'action'=>'form'
      );
      $editFormString = Foswiki::Func::expandTemplate('EDITFORM_ACTION');
      $editFormString =~ s/%\$url%/$url/g;
    }
  }

  # edit text
  if ($text =~ /\$edittext\b/) {
    if ($isRestrictedAction{'edit'}) {
      $editTextString = Foswiki::Func::expandTemplate('EDITTEXT_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "edit", $baseWeb, $baseTopic,
        't'=> time(),
        'action'=>'text'
      );
      $editTextString = Foswiki::Func::expandTemplate('EDITTEXT_ACTION_RESTRICTED');
      $editTextString =~ s/%\$url%/$url/g;
    }
  }

  # attach
  if ($text =~ /\$attach\b/) {
    if ($isRestrictedAction{'attach'}) {
      $attachString = Foswiki::Func::expandTemplate('ATTACH_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "attach", $baseWeb, $baseTopic);
      $attachString = Foswiki::Func::expandTemplate('ATTACH_ACTION');
      $attachString =~ s/%\$url%/$url/g;
    }
  }

  # delete
  if ($text =~ /\$delete\b/) {
    if ($isRestrictedAction{'delete'}) {
      $deleteString = Foswiki::Func::expandTemplate('DELETE_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "rename", $baseWeb, $baseTopic, 
        'currentwebonly'=>'on', 'newweb'=>$Foswiki::cfg{TrashWebName});
      $deleteString = Foswiki::Func::expandTemplate('DELETE_ACTION');
      $deleteString =~ s/%\$url%/$url/g;
    }
  }

  # move/rename
  if ($text =~ /\$move\b/) {
    if ($isRestrictedAction{'move'}) {
      $moveString = Foswiki::Func::expandTemplate('MOVE_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "rename", $baseWeb, $baseTopic, 
        'currentwebonly'=>'on'
      );
      $moveString = Foswiki::Func::expandTemplate('MOVE_ACTION');
      $moveString =~ s/%\$url%/$url/g;
    }
  }

  # close
  if ($text =~ /\$close\b/) {
    if ($isRestrictedAction{'close'}) {
      $closeString = Foswiki::Func::expandTemplate('CLOSE_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "view", $baseWeb, $baseTopic);
      $closeString = Foswiki::Func::expandTemplate('CLOSE_ACTION');
      $closeString =~ s/%\$url%/$url/g;
    }
  }

  # raw
  if ($text =~ /\$raw\b/) {
    if ($isRestrictedAction{'raw'}) {
      if ($isRaw) {
        $rawString = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
      } else {
        $rawString = Foswiki::Func::expandTemplate('RAW_ACTION_RESTRICTED');
      }
    } else {
      my $revParam = $skinState{"history"}?"?rev=$curRev":'';
      if ($isRaw) {
        my $url = $session->getScriptUrl(0, "view", $baseWeb, $baseTopic).$revParam;
        $rawString = Foswiki::Func::expandTemplate('VIEW_ACTION');
        $rawString =~ s/%\$url%/$url/g;
      } else {
        my $rawParam = $skinState{"history"}?"&rev=$curRev":'';
        my $url = $session->getScriptUrl(0, "view", $baseWeb, $baseTopic) .'?raw=on'.$rawParam;
        $rawString = Foswiki::Func::expandTemplate('RAW_ACTION');
        $rawString =~ s/%\$url%/$url/g;
      }
    }
  }
  
  # history
  if ($text =~ /\$history\b/) {
    if ($isRestrictedAction{'history'}) {
      $historyString = Foswiki::Func::expandTemplate('HISTORY_ACTION_RESTRICTED');
    } else {
      my $url = getDiffUrl($session);
      $historyString = Foswiki::Func::expandTemplate('HISTORY_ACTION');
      $historyString =~ s/%\$url%/$url/g;
    }
  }

  # more
  if ($text =~ /\$more\b/) {
    if ($isRestrictedAction{'more'}) {
      $moreString = Foswiki::Func::expandTemplate('MORE_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, "oops", $baseWeb, $baseTopic,
        'template'=>'oopsmore'
      );
      $moreString = Foswiki::Func::expandTemplate('MORE_ACTION');
      $moreString =~ s/%\$url%/$url/g;
    }
  }

  # print
  if ($text =~ /\$print\b/) {
    if ($isRestrictedAction{'print'}) {
      $printString = Foswiki::Func::expandTemplate('PRINT_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, 'view', $baseWeb, $baseTopic, 
        'cover'=>'print.nat'
      );
      $printString = Foswiki::Func::expandTemplate('PRINT_ACTION');
      $printString =~ s/%\$url%/$url/g;
    }
  }

  # pdf
  if ($text =~ /\$pdf\b/) {
    if ($isRestrictedAction{'pdf'}) {
      $pdfString = Foswiki::Func::expandTemplate('PDF_ACTION_RESTRICTED');
    } else {
      my $url;
      my $context = Foswiki::Func::getContext();
      if ($context->{GenPDFPrincePluginEnabled} ||
          $context->{GenPDFWebkitPluginEnabled}) {
        $url = $session->getScriptUrl(0, 'view', $baseWeb, $baseTopic, 
          'contenttype'=>'application/pdf');
      } else {
        # SMELL: can't check for GenPDFAddOn reliably; we'd like to 
        # default to normal printing if no other print helper is installed
        $url = $session->getScriptUrl(0, 'genpdf', $baseWeb, $baseTopic, 
          'cover'=>'print.nat',
        );
      }
      $pdfString = Foswiki::Func::expandTemplate('PDF_ACTION');
      $pdfString =~ s/%\$url%/$url/g;
    }
  }

  # subscribe
  if ($text =~ /\$subscribe\b/) {
    if ($isRestrictedAction{'subscribe'}) {
      $subscribeString = Foswiki::Func::expandTemplate('SUBSCRIBE_ACTION_RESTRICTED');
    } else {
      $subscribeString = Foswiki::Func::expandTemplate('SUBSCRIBE_ACTION');
    }
  }

  # login
  if ($text =~ /\$login\b/) {
    my $loginUrl = getLoginUrl();
    if ($loginUrl) {
      if ($isRestrictedAction{'login'}) {
        $loginString = Foswiki::Func::expandTemplate('LOG_IN_ACTION_RESTRICTED');
      } else {
        $loginString = Foswiki::Func::expandTemplate('LOG_IN_ACTION');
        $loginString =~ s/%\$url%/$loginUrl/g;
      }
    } else {
      $loginString = '';
    }
  }

  # logout
  if ($text =~ /\$logout\b/) {
    my $logoutUrl = getLogoutUrl();
    if ($logoutUrl) {
      if ($isRestrictedAction{'logout'}) {
        $logoutString = Foswiki::Func::expandTemplate('LOG_OUT_ACTION_RESTRICTED');
      } else {
        $logoutString = Foswiki::Func::expandTemplate('LOG_OUT_ACTION');
        $logoutString =~ s/%\$url%/$logoutUrl/g;
      }
    } else {
      $logoutString = '';
    }
  }

  # registration
  if ($text =~ /\$register\b/) {
    my $userRegistrationTopic= renderUserRegistration();
    if ($userRegistrationTopic) {
      if ($isRestrictedAction{'register'}) {
        $registerString = Foswiki::Func::expandTemplate('REGISTER_ACTION_RESTRICTED');
      } else {
        my $url = $session->getScriptUrl(0, 'view', $baseWeb, $userRegistrationTopic);
        $registerString = Foswiki::Func::expandTemplate('REGISTER_ACTION');
        $registerString =~ s/%\$url%/$url/g;
      }
    }
  }

  # help
  if ($text =~ /\$help\b/) {
    if ($isRestrictedAction{'help'}) {
      $helpString = Foswiki::Func::expandTemplate('HELP_ACTION_RESTRICTED');
    } else {
      my $systemWeb = $Foswiki::cfg{SystemWebName};
      my $helpTopic = $params->{help} || "UsersGuide";
      my $helpWeb;
      ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($systemWeb, $helpTopic);
      my $url = $session->getScriptUrl(0, 'view', $helpWeb, $helpTopic);
      $helpString = Foswiki::Func::expandTemplate('HELP_ACTION');
      $helpString =~ s/%\$url%/$url/g;
    }
  }

  # account string
  if ($text =~ /\$account\b/) {
    my $usersWeb = $Foswiki::cfg{UsersWebName};
    my $wikiName = Foswiki::Func::getWikiName();
    if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
      my $url = $session->getScriptUrl(0, "view", $usersWeb, $wikiName);
      $accountString = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
      $accountString =~ s/%\$url%/$url/g;
    } else {
      $accountString = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
    }
  }

  # users string
  if ($text =~ /\$users\b/) {
    if ($isRestrictedAction{'users'}) {
      $usersString = Foswiki::Func::expandTemplate('USERS_ACTION_RESTRICTED');
    } else {
      $usersString = Foswiki::Func::expandTemplate('USERS_ACTION');
    }
  } 

  # first revision
  if ($text =~ /\$first\b/) {
    if ($isRestrictedAction{'first'} || $curRev == 1+$nrRev) {
      $firstString = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
    } else {
      my $url = $session->getScriptUrl(0, $diffCommand, $baseWeb, $baseTopic,
        'rev1'=>1,
        'rev2'=>(1+$nrRev),
        'render'=>$renderMode
      );
      $firstString = Foswiki::Func::expandTemplate('FIRST_ACTION');
      $firstString =~ s/%\$url%/$url/g;
    }
  }

  # next revision
  if ($text =~ /\$next\b/) {
    if ($isRestrictedAction{'next'} || $nextRev > $maxRev) {
      $nextString = Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, $diffCommand, $baseWeb, $baseTopic,
        'rev1'=>$curRev,
        'rev2'=>$nextRev,
        'render'=>$renderMode
      );
      $nextString = Foswiki::Func::expandTemplate('NEXT_ACTION');
      $nextString =~ s/%\$url%/$url/g;
    }
  }

  # prev revision
  if ($text =~ /\$prev\b/) {
    if ($isRestrictedAction{'prev'} || $prevRev <= 1) {
      $prevString = Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, $diffCommand, $baseWeb, $baseTopic,
        'rev1'=>($prevRev-$nrRev),
        'rev2'=>$prevRev,
        'render'=>$renderMode
      );
      $prevString = Foswiki::Func::expandTemplate('PREV_ACTION');
      $prevString =~ s/%\$url%/$url/g;
    }
  }

  # last revision
  if ($text =~ /\$last\b/) {
    if ($isRestrictedAction{'last'} || $curRev == $maxRev) {
      $lastString = Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, $diffCommand, $baseWeb, $baseTopic,
        'rev1'=>($maxRev-$nrRev),
        'rev2'=>$maxRev,
        'render'=>$renderMode
      );
      $lastString = Foswiki::Func::expandTemplate('LAST_ACTION');
      $lastString =~ s/%\$url%/$url/g;
    }
  }

  # rdiff
  if ($text =~ /\$diff/) {
    if ($isRestrictedAction{'diff'} || $prevRev < 1) {
      $diffString = Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
    } else {
      my $url = $session->getScriptUrl(0, $diffCommand, $baseWeb, $baseTopic,
        'rev1'=>$prevRev,
        'rev2'=>$curRev,
        'render'=>$renderMode
      );
      $diffString = Foswiki::Func::expandTemplate('DIFF_ACTION');
      $diffString =~ s/%\$url%/$url/g;
    }
  }

  $text =~ s/\$new/$newString/g;
  $text =~ s/\$editform/$editFormString/g;
  $text =~ s/\$edittext/$editTextString/g;
  $text =~ s/\$edit/$editString/g;
  $text =~ s/\$attach/$attachString/g;
  $text =~ s/\$move/$moveString/g;
  $text =~ s/\$delete/$deleteString/g;
  $text =~ s/\$raw/$rawString/g;
  $text =~ s/\$history/$historyString/g;
  $text =~ s/\$more/$moreString/g;
  $text =~ s/\$print/$printString/g;
  $text =~ s/\$pdf/$pdfString/g;
  $text =~ s/\$login/$loginString/g;
  $text =~ s/\$register/$registerString/g;
  $text =~ s/\$account/$accountString/g;
  $text =~ s/\$users/$usersString/g;
  $text =~ s/\$subscribe/$subscribeString/g;
  $text =~ s/\$help/$helpString/g;
  $text =~ s/\$first/$firstString/g;
  $text =~ s/\$last/$lastString/g;
  $text =~ s/\$next/$nextString/g;
  $text =~ s/\$prev/$prevString/g;
  $text =~ s/\$close/$closeString/g;
  $text =~ s/\$diff/$diffString/g;
  $text =~ s/\$sep\$logout//g unless $logoutString;
  $text =~ s/\$logout/$logoutString/g;
  $text =~ s/\$sep/$sepString/g;

  return $header.$text.$footer;
}

###############################################################################
# returns the login url
sub getLoginUrl {
  my $session = $Foswiki::Plugins::SESSION;
  return '' unless $session;

  my $loginManager = $session->{loginManager} || # TMwiki-4.2
    $session->{users}->{loginManager} || # TMwiki-4.???
    $session->{client} || # TMwiki-4.0
    $session->{users}->{loginManager}; # Foswiki

  return $loginManager->loginUrl();
}

###############################################################################
# display url to logout
sub getLogoutUrl {
  my $session = $Foswiki::Plugins::SESSION;
  return '' unless $session;

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->logoutUrl();
  #
  # but for now the "best" we can do is this:
  my $loginManager = $Foswiki::cfg{LoginManager};
  if ($loginManager =~ /ApacheLogin/) {
    return '';
  } 
  
  return $session->getScriptUrl(0, 'view', $baseWeb, $baseTopic, logout=>1);
}

###############################################################################
# display url to enter topic diff/history
sub getDiffUrl {
  my $session = shift;

  my $diffTemplate = $session->inContext("HistoryPluginEnabled")?'oopshistory':'oopsrev';
  my $prevRev = getPrevRevision($baseWeb, $baseTopic);
  my $curRev = getCurRevision($baseWeb, $baseTopic);
  my $maxRev = getMaxRevision($baseWeb, $baseTopic);
  return $session->getScriptUrl(0, "oops", $baseWeb, $baseTopic) . 
      '?template='.$diffTemplate.
      "&param1=$prevRev&param2=$curRev&param3=$maxRev";
}


###############################################################################
sub renderWebComponent {
  my ($session, $params) = @_;

  my $theComponent = $params->{_DEFAULT};
  my $theLinePrefix = $params->{lineprefix};
  my $theWeb = $params->{web};
  my $theMultiple = $params->{multiple};

  my $name = lc $theComponent;

  return '' if $skinState{$name} && $skinState{$name} eq 'off';

  my $text;
  ($text, $theWeb, $theComponent) = getWebComponent($theWeb, $theComponent, $theMultiple);

  #SL: As opposed to INCLUDE WEBCOMPONENT should render as if they were in the web they provide links to.
  #    This behavior allows for web component to be consistently rendered in foreign web using the =web= parameter. 
  #    It makes sure %WEB% is expanded to the appropriate value. 
  #    Although possible, usage of %BASEWEB% in web component topics might have undesired effect when web component is rendered from a foreign web. 
  $text = Foswiki::Func::expandCommonVariables($text, $theComponent, $theWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;
  $text =~ s/[\n\r]+/\n$theLinePrefix/gs if defined $theLinePrefix;

  return $text
}

###############################################################################
# search path 
# 1. search WebTheComponent in current web
# 2. search SiteTheComponent in %USERWEB% 
# 3. search SiteTheComponent in %SYSTEMWEB%
# 4. search WebTheComponent in %SYSTEMWEB% web
# (like: TheComponent = SideBar)
sub getWebComponent {
  my ($web, $component, $multiple) = @_;

  $web ||= $baseWeb; # Default to $baseWeb NOTE
  $multiple || 0;
  $component =~ s/^(Web)//; #compatibility

  ($web, $component) = Foswiki::Func::normalizeWebTopicName($web, $component);

  #writeDebug("called getWebComponent($component)");

  # SMELL: why does preview call for components twice ???
  if ($seenWebComponent{$component} && $seenWebComponent{$component} > 2 && !$multiple) {
    return '<span class="foswikiAlert">'.
      "ERROR: component '$component' already included".
      '</span>';
  }
  $seenWebComponent{$component}++;

  # get component for web
  my $text = '';
  my $meta = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $systemWeb = $Foswiki::cfg{SystemWebName};

  my $theWeb = $web;
  my $targetWeb = $web;
  my $theComponent = 'Web'.$component;

  my $userName = Foswiki::Func::getWikiName();

  if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
      Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
    # current
    ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $usersWeb;
    $theComponent = 'Site'.$component;


    if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
        Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
      # %USERWEB%
      ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $systemWeb;

      if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
          Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	# %SYSTEMWEB%
	($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
      } else {
	$theWeb = $systemWeb;
	$theComponent = 'Web'.$component;
	if (Foswiki::Func::topicExists($theWeb, $theComponent) &&
            Foswiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	  ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
	} else {
	  return ''; # not found
	}
      }
    }
  }

  # extract INCLUDE area
  $text =~ s/.*?%STARTINCLUDE%//gs;
  $text =~ s/%STOPINCLUDE%.*//gs;

  #writeDebug("done getWebComponent($web.$component)");

  return ($text, $theWeb, $theComponent);
}

###############################################################################
sub renderWebLink {
  my ($session, $params) = @_;

  # get params
  my $theWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  my $theName = $params->{name};
  my $theMarker = $params->{marker} || 'current';

  my $defaultFormat =
    '<a class="natWebLink $marker" href="$url" title="$tooltip">$name</a>';

  my $theFormat = $params->{format} || $defaultFormat;


  my $theTooltip = $params->{tooltip} ||
    Foswiki::Func::getPreferencesValue('SITEMAPUSETO', $theWeb) || '';

  my $homeTopic = Foswiki::Func::getPreferencesValue('HOMETOPIC') 
    || $Foswiki::cfg{HomeTopicName} 
    || 'WebHome';

  my $theUrl = $params->{url} ||
    $session->getScriptUrl(0, 'view', $theWeb, $homeTopic);

  # unset the marker if this is not the current web 
  $theMarker = '' unless $theWeb eq $baseWeb;

  # normalize web name
  $theWeb =~ s/\//\./go;

  # get a good default name
  unless ($theName) {
    $theName = $theWeb;
    $theName = $2 if $theName =~ /^(.*)[\.](.*?)$/;
  }

  # escape some disturbing chars
  if ($theTooltip) {
    $theTooltip =~ s/"/&quot;/g;
    $theTooltip =~ s/<nop>/#nop#/g;
    $theTooltip =~ s/<[^>]*>//g;
    $theTooltip =~ s/#nop#/<nop>/g;
  }

  my $result = $theFormat;
  $result =~ s/\$default/$defaultFormat/g;
  $result =~ s/\$marker/$theMarker/g;
  $result =~ s/\$url/$theUrl/g;
  $result =~ s/\$tooltip/$theTooltip/g;
  $result =~ s/\$name/$theName/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$homeTopic/g;

  return $result;
}


#############################################################################
# returns the weblogo for the header bar.
# this will check for a couple of preferences:
#    * return %NATWEBLOGONAME% if defined
#    * return %NATWEBLOGOIMG% if defined
#    * return %WIKILOGOIMG% if defined
#    * return %WEBLOGOIMG% if defined
#    * return %WIKITOOLNAME% if defined
#    * or return 'Foswiki'
#
# the ...IMG% settings are urls to images where the following variables 
# are substituted:
#    * $style: the lower case id of the current style 
#    * $variation: the lower case id of the current variation
#
# this allows to switch the logo while switching the style and/or variation.
# 
# the *IMG cases will return a full <img src /> tag
#
sub renderNatWebLogo {
  my ($session, $params) = @_;

  my $name = Foswiki::Func::getPreferencesValue('NATWEBLOGONAME');
  
  my $wikiLogoImage = Foswiki::Func::getPreferencesValue('WIKILOGOIMG');
  my $image = 
    Foswiki::Func::getPreferencesValue('NATWEBLOGOIMG') || 
    Foswiki::Func::getPreferencesValue('WEBLOGOIMG') || 
    $wikiLogoImage;

  # HACK: override ProjectLogos with own version
  $image =~ s/\%WIKILOGOIMG%/$wikiLogoImage/g;
  $image =~ s/ProjectLogos/NatSkin/o; 

  my $alt = 
    Foswiki::Func::getPreferencesValue('NATWEBLOGOALT') || 
    Foswiki::Func::getPreferencesValue('WEBLOGOALT') || 
    Foswiki::Func::getPreferencesValue('WIKILOGOALT') || 
    Foswiki::Func::getPreferencesValue('WIKITOOLNAME') || 
    'Foswiki';
  
  my $url = Foswiki::Func::getPreferencesValue('NATWEBLOGOURL') ||
    Foswiki::Func::getPreferencesValue('WEBLOGOURL') ||
    Foswiki::Func::getPreferencesValue('WIKILOGOURL') ||
    Foswiki::Func::getPreferencesValue('%SCRIPTURLPATH{"view"}%/%USERSWEB%/%HOMETOPIC%');

  my $variation = lc $skinState{variation};
  my $style = lc $skinState{style};

  my $format = $params->{format};
  $format = '<a href="$url" title="$alt">$logo</a>' unless defined $format;

  my $logo;
  if ($name) {
    $logo = '<span class="natWebLogo">$name</span>';
  } elsif ($image) {
    $logo = '<img class="natWebLogo" src="$src" alt="$alt" border="0" />';
  } else {
    $logo = '<span class="natWebLogo">Foswiki</span>';
  }

  my $themeRecord = getThemeRecord($skinState{'style'});
  my $path = $themeRecord?$themeRecord->{path}:'';
  
  my $result = $format;
  $result =~ s/\$logo/$logo/g;
  $result =~ s/\$src/$image/g;
  $result =~ s/\$url/$url/g;
  $result =~ s/\$path/$themeRecord->{path}/g;
  $result =~ s/\$variation/$variation/g;
  $result =~ s/\$style/$style/g;
  $result =~ s/\$alt/$alt/g;
  $result =~ s/\$name/$name/g;

  return $result;
}

#############################################################################
sub renderNatStyleUrl {
  my $theStyle = lc($skinState{'style'});
  my $themeRecord = getThemeRecord($theStyle);
  return $themeRecord->{styles}{$theStyle};
}

###############################################################################
sub renderRevisions {

  #writeDebug("called renderRevisions");
  my $rev1;
  my $rev2;
  $rev1 = $request->param("rev1") if $request;
  $rev2 = $request->param("rev2") if $request;

  my $topicExists = Foswiki::Func::topicExists($baseWeb, $baseTopic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    my $maxRev = getMaxRevision();
    $rev1 = $maxRev if $rev1 < 1;
    $rev1 = $maxRev if $rev1 > $maxRev;
    $rev2 = 1 if $rev2 < 1;
    $rev2 = $maxRev if $rev2 > $maxRev;

  } else {
    $rev1 = 1;
    $rev2 = 1;
  }

  my $revisions = '';
  my $nrrevs = $rev1 - $rev2;
  my $numberOfRevisions = $Foswiki::cfg{NumberOfRevisions};

  if ($nrrevs > $numberOfRevisions) {
    $nrrevs = $numberOfRevisions;
  }

  #writeDebug("rev1=$rev1, rev2=$rev2, nrrevs=$nrrevs");

  my $j = $rev1 - $nrrevs;
  for (my $i = $rev1; $i >= $j; $i -= 1) {
    $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"view"}%'.
      '/%WEB%/%TOPIC%?rev='.$i.'">r'.$i.'</a>';
    if ($i == $j) {
      my $torev = $j - $nrrevs;
      $torev = 1 if $torev < 0;
      if ($j != $torev) {
	$revisions = $revisions.
	  '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	  '/%WEB%/%TOPIC%?rev1='.$j.'&amp;rev2='.$torev.'">...</a>';
      }
      last;
    } else {
      $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	'/%WEB%/%TOPIC%?rev1='.$i.'&amp;rev2='.($i-1).'">&gt;</a>';
    }
  }

  return $revisions;
}

###############################################################################
# reused code from the BlackListPlugin
sub renderExternalLink {
  my ($thePrefix, $theUrl) = @_;

  my $addClass = 0;
  my $text = $thePrefix.$theUrl;
  my $urlHost = Foswiki::Func::getUrlHost();
  my $httpsUrlHost = $urlHost;
  $httpsUrlHost =~ s/^http:\/\//https:\/\//go;

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $theUrl =~ /^$httpsUrlHost/i && ($addClass = 0); # not for own host
  $thePrefix =~ /class="[^"]*\bnop\b/ && ($addClass = 0); # prevent adding it 
  $thePrefix =~ /class="natExternalLink"/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
    #writeDebug("called renderExternalLink($thePrefix, $theUrl)");
    $text = "class=\"natExternalLink\" target=\"_blank\" $thePrefix$theUrl";
    #writeDebug("text=$text");
  }

  return $text;
}

###############################################################################
sub renderPrevRevision {
  return getPrevRevision($baseWeb, $baseTopic);
}

###############################################################################
sub renderCurRevision {
  return getCurRevision($baseWeb, $baseTopic);
}

###############################################################################
sub renderMaxRevision {
  return getMaxRevision($baseWeb, $baseTopic);
}

###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic) = @_;

  my $rev;
  if ($request) {
    $rev = $request->param("rev");
    unless (defined $rev) {
      if ($skinState{'action'} =~ /compare|rdiff/) {
        my $rev1 = $request->param("rev1");
        my $rev2 = $request->param("rev2");
        if ($rev1 && $rev2) {
          $rev = ($rev1 > $rev2)?$rev1:$rev2;
        }
      }
    }
  }

  if ($rev) {
    $rev =~ s/r?1\.//go;
  } else {
    (undef, undef, $rev) = 
      Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic);
  }

  return $rev;
}

###############################################################################
sub getPrevRevision {
  my ($thisWeb, $thisTopic) = @_;
  my $rev;
  $rev = $request->param("rev") if $request;

  my $numberOfRevisions = $Foswiki::cfg{NumberOfRevisions};

  $rev = getMaxRevision($thisWeb, $thisTopic) unless $rev;
  $rev =~ s/r?1\.//go; # cut major
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

  $thisWeb = $baseWeb unless $thisWeb;
  $thisTopic = $baseTopic unless $thisTopic;

  my $maxRev = $maxRevs{"$thisWeb.$thisTopic"};
  return $maxRev if defined $maxRev;

  (undef, undef, $maxRev) = Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic);

  $maxRev =~ s/r?1\.//go;  # cut 'r' and major
  $maxRevs{"$thisWeb.$thisTopic"} = $maxRev;
  return $maxRev;
}

###############################################################################
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (rewrites, aliases)
sub getRequestAction {

  my $theAction;

  unless (defined($request->VERSION)) { # Foswiki::Request
    $theAction = $request->action();
  } 

  unless ($theAction) { # fallback
    my $context = Foswiki::Func::getContext();

    # not all cgi actions we want to distinguish set their context
    # to a known value. so only use those we are sure of
    return 'attach' if $context->{'attach'};
    return 'changes' if $context->{'changes'};
    return 'edit' if $context->{'edit'};
    return 'login' if $context->{'login'};
    return 'manage' if $context->{'manage'};
    return 'oops' if $context->{'oops'};
    return 'preview' if $context->{'preview'};
    return 'diff' if $context->{'diff'};
    return 'compare' if $context->{'compare'};
    return 'register' if $context->{'register'};
    return 'rename' if $context->{'rename'};
    return 'resetpasswd' if $context->{'resetpasswd'};
    return 'rest' if $context->{'rest'};
    return 'save' if $context->{'save'};
    return 'search' if $context->{'search'};
    return 'statistics' if $context->{'statistics'};
    return 'upload' if $context->{'upload'};
    return 'view' if $context->{'view'};
    return 'view' if $context->{'viewauth'};
    return 'viewfile' if $context->{'viewfile'};

    # fall back to analyzing the path info
    my $pathInfo = $ENV{'PATH_INFO'} || '';
    $theAction = $ENV{'REQUEST_URI'} || '';
    if ($theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
      $theAction = $1;
    } else {
      $theAction = 'view';
    }

  }
  
  #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
  #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
  #writeDebug("theAction=$theAction");

  return $theAction;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\\n/\n/g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\\%/%/g;
  $_[0] =~ s/\\"/"/g;
  $_[0] =~ s/\$dollar/\$/g;
}

###############################################################################
# from Foswiki.pm
sub isTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ($value) ? 1 : 0;
}

1;

