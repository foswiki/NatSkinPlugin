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

package Foswiki::Plugins::NatSkinPlugin::UserActions;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();

###############################################################################
sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = {
    session => $session,
    @_
  };

  bless($this, $class);


  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  foreach my $key (keys %$this) {
    undef $this->{$key};
  }
}


###############################################################################
sub init {
  my ($this, $session, $params, $web, $topic) = @_;

  $this->{session} = $session;
  $this->{topic} = $topic;
  $this->{web} = $web;
  $this->{baseTopic} = $this->{session}{topicName};
  $this->{baseWeb} = $this->{session}{webName};
  $this->{menu} = $params->{menu};
  $this->{menu_header} = $params->{menu_header};
  $this->{menu_footer} = $params->{menu_footer};
  $this->{hiderestricted} = Foswiki::Func::isTrue($params->{hiderestricted}, 0);
  $this->{mode} = $params->{mode} || 'short';
  $this->{sep} = $params->{sep} || $params->{separator} || '';

  my $context = Foswiki::Func::getContext();

  # get restrictions
  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'attach,delete,diff,edit,harvest,managetags,more,move,raw,restore'
    unless defined $restrictedActions;
  %{$this->{isRestrictedAction}} = map { $_ => 1 } split(/\s*,\s*/, $restrictedActions);

  # set can_generate_pdf context
  # SMELL: how do we detect GenPDFAddOn...see also getPdfUrl

  if ( $context->{GenPDFPrincePluginEnabled}
    || $context->{GenPDFWebkitPluginEnabled}
    || $context->{GenPDFOfficePluginEnabled}
    || $context->{GenPDFWeasyPluginEnabled}
    || $context->{PdfPluginEnabled})
  {
    $context->{can_generate_pdf} = 1;
  }

  # a guest can't subscribe to changes
  if (Foswiki::Func::isGuest()) {
    $this->{isRestrictedAction}{'subscribe'} = 1;
  }

  # list all actions that need edit rights
  if ($this->{isRestrictedAction}{'edit'}) {
    $this->{isRestrictedAction}{'attach'} = 1;
    $this->{isRestrictedAction}{'delete'} = 1;
    $this->{isRestrictedAction}{'edit_form'} = 1;
    $this->{isRestrictedAction}{'edit_raw'} = 1;
    $this->{isRestrictedAction}{'edit_settings'} = 1;
    $this->{isRestrictedAction}{'edit_text'} = 1;
    $this->{isRestrictedAction}{'harvest'} = 1;
    $this->{isRestrictedAction}{'move'} = 1;
    $this->{isRestrictedAction}{'restore'} = 1;
    $this->{isRestrictedAction}{'webdavdir'} = 1;
  }

  # if you've got access to this topic then all actions are allowed
  my $wikiName = Foswiki::Func::getWikiName();
  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $this->{baseTopic}, $this->{baseWeb});

  # support for old WorkflowPlugin 
# if ($gotAccess && Foswiki::Func::getContext()->{WorkflowPluginEnabled}) {
#   require Foswiki::Plugins::WorkflowPlugin;
#   my $controlledTopic = Foswiki::Plugins::WorkflowPlugin::_initTOPIC($this->{baseWeb}, $this->{baseTopic});
#   if ($controlledTopic && !$controlledTopic->canEdit()) {
#     $gotAccess = 0;
#   }
# }

  my $gotWebAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, undef, $this->{baseWeb});
  
  $this->{isRestrictedAction} = () if $gotAccess;
  $this->{isRestrictedAction}{'new'} = 1 unless $gotWebAccess;

  my $request = Foswiki::Func::getCgiQuery();
  $this->{isRaw} = ($request) ? $request->param('raw') : '';

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();
  $this->{isHistory} = ($themeEngine->{skinState}{"history"})?1:0;

  my $isCompare = ($themeEngine->{skinState}{'action'} eq 'compare') ? 1 : 0;
  my $isRdiff = ($themeEngine->{skinState}{'action'} eq 'rdiff') ? 1 : 0;
  my $isDiff = ($themeEngine->{skinState}{'action'} eq 'diff') ? 1 : 0;
  $this->{action} = 'view';
  $this->{action} = 'compare' if $isCompare;
  $this->{action} = 'rdiff' if $isRdiff;
  $this->{action} = 'diff' if $isDiff;

  # disable registration
  unless ($context->{registration_enabled}) {
    $this->{isRestrictedAction}{'register'} = 1;
  }


  return $this;
}

###############################################################################
sub render {
  my ($this, $session, $params, $topic, $web) = @_;

  $this->init($session, $params, $web, $topic);

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';

  my $text = $params->{_DEFAULT} || $params->{format};
  $text = '$edit$sep$attach$sep$new$sep$raw$sep$delete$sep$history$sepprint$sep$more'
    unless defined $text;

  my $context = Foswiki::Func::getContext();

  my $guestText = $params->{guest};
  $guestText = '$login$sep$register' unless defined $guestText;

  $text = $guestText unless $context->{authenticated};

  if ($this->{isHistory}) {
    my $historyText = $params->{history};
    $text = $historyText if defined $historyText;
  }
  return '' unless $text;

  $text = $this->formatResult($text);
  return '' unless $text;

  return Foswiki::Func::decodeFormatTokens($header . $text . $footer);
}

###############################################################################
sub formatResult {
  my ($this, $text, $mode) = @_;

  $mode ||= $this->{mode} || 'short';

  # menu can contain actions. so it goes first
  $text =~ s/\$menu/$this->renderMenu($mode)/ge;

  # special actions
  $text =~ s/\$(?:edit_form\b|action\(edit_form(?:,\s*(.*?))?\))/$this->renderEditForm($1, $mode)/ge;
  $text =~ s/\$(?:edit_raw\b|action\(edit_raw(?:,\s*(.*?))?\))/$this->renderEditRaw($1, $mode)/ge;
  $text =~ s/\$(?:edit\b|action\(edit(?:,\s*(.*?))?\))/$this->renderEdit($1, $mode)/ge;
  $text =~ s/\$(?:account\b|action\(account(?:,\s*(.*?))?\))/$this->renderAccount($1, $mode)/ge;
  $text =~ s/\$(?:diff\b|action\(diff(?:,\s*(.*?))?\))/$this->renderDiff($1, $mode)/ge;
  $text =~ s/\$(?:view\b|action\(view(?:,\s*(.*?))?\))/$this->renderView($1, $mode)/ge;
  $text =~ s/\$(?:first\b|action\(first(?:,\s*(.*?))?\))/$this->renderFirst($1, $mode)/ge;
  $text =~ s/\$(?:last\b|action\(last(?:,\s*(.*?))?\))/$this->renderLast($1, $mode)/ge;
  $text =~ s/\$(?:login\b|action\(login(?:,\s*(.*?))?\))/$this->renderLogin($1, $mode)/ge;
  $text =~ s/\$(?:next\b|action\(next(?:,\s*(.*?))?\))/$this->renderNext($1, $mode)/ge;
  $text =~ s/\$(?:prev\b|action\(prev(?:,\s*(.*?))?\))/$this->renderPrev($1, $mode)/ge;
  $text =~ s/\$(?:raw\b|action\(raw(?:,\s*(.*?))?\))/$this->renderRaw($1, $mode)/ge;
  $text =~ s/(\$sep)?\$(?:logout\b|action\(logout(?:,\s*(.*?))?\))/$this->renderLogout($1, $2, $mode)/ge;

  # normal actions 
  $text =~ s/\$(attach|copytopic|delete|edit_settings|edit_text|help|history|more|move|new|pdf|print|register|restore|users|share|like)\b/$this->renderAction($1, undef, undef, undef, $mode)/ge;

  # generic actions
  $text =~ s/\$action\((.*?)(?:,\s*(.*?))?\)/$this->renderAction($1, undef, undef, $2, $mode)/ge;

  # action urls
  $text =~ s/\$diffurl\b/$this->getDiffUrl()/ge;
  $text =~ s/\$editurl\b/$this->getEditUrl()/ge;
  $text =~ s/\$restoreurl\b/$this->getRestoreUrl()/ge;
  $text =~ s/\$firsturl\b/$this->getFirstUrl()/ge;
  $text =~ s/\$prevurl\b/$this->getPrevUrl()/ge;
  $text =~ s/\$nexturl\b/$this->getNextUrl()/ge;
  $text =~ s/\$lasturl\b/$this->getLastUrl()/ge;
  $text =~ s/\$helpurl\b/$this->getHelpUrl()/ge;
  $text =~ s/\$loginurl\b/$this->getLoginUrl()/ge;
  $text =~ s/\$logouturl/$this->getLogoutUrl()/ge;
  $text =~ s/\$registerurl/$this->getRegisterUrl()/ge;
  $text =~ s/\$pdfurl\b/$this->getPdfUrl()/ge;

  $text =~ s/\$sep\b/$this->{sep}/g;
  $text =~ s/\$restorerev\b/$this->getRestoreRev()/ge;
  $text =~ s/\$rev\b/$this->getRev()/ge;

  $mode = uc($mode);
  $text =~ s/\$mode\b/$mode/g;

  return $text;
}

###############################################################################
sub renderAction {
  my ($this, $action, $template, $restrictedTemplate, $context, $mode) = @_;

  #print STDERR "called renderAction($action,".($context?"'".$context."'":'').")\n";

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  $template = uc($action) . "_ACTION" unless defined $template;
  $restrictedTemplate = uc($action) . "_ACTION_RESTRICTED" unless defined $restrictedTemplate;

  my $result = '';
  if ($this->{isRestrictedAction}{$action}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate($restrictedTemplate);
  } else {
    $result = Foswiki::Func::expandTemplate($template);
  }

  my $label = $this->getLabelForAction(uc($action), $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderEdit {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{'edit'}) {
    return '' if $this->{hiderestricted};
    if ($this->{isHistory}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("EDIT", $mode);
    }
  } else {
    if ($this->{isHistory}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION');
      $label = $this->getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION');
      $label = $this->getLabelForAction("EDIT", $mode);
    }
  }

  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderEditRaw {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{'edit_raw'}) {
    return '' if $this->{hiderestricted};
    if ($this->{isHistory}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_RAW_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("EDIT_RAW", $mode);
    }
  } else {
    if ($this->{isHistory}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION');
      $label = $this->getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_RAW_ACTION');
      $label = $this->getLabelForAction("EDIT_RAW", $mode);
    }
  }

  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderView {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  if ($this->{isRestrictedAction}{'view'}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
  } else {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();
    if ($themeEngine->{skinState}{"action"} eq 'view') {
      return '';
    } else {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
    }
  }

  my $label = $this->getLabelForAction("VIEW", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getEditUrl {
  my $this = shift;
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef, 't' => time(),);
}

###############################################################################
sub getRestoreRev {
  my $this = shift;

  my $rev = $this->getCurRev() - 1;
  $rev = 1 if $rev < 1;

  return $rev;
}

###############################################################################
sub getRestoreUrl {
  my $this = shift;

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    "edit", undef, undef,
    't' => time(),
    'rev' => $this->getRestoreRev()
  );
}

###############################################################################
sub renderRaw {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{'raw'}) {
    return '' if $this->{hiderestricted};
    if ($this->{isRaw}) {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("VIEW", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('RAW_ACTION_RESTRICTED');
      $label = $this->getLabelForAction("RAW", $mode);
    }
  } else {
    if ($this->{isRaw}) {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
      $label = $this->getLabelForAction("VIEW", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('RAW_ACTION');
      $label = $this->getLabelForAction("RAW", $mode);
    }
  }

  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderMenu {
  my ($this, $mode) = @_;

  my $result = '';

  if ($this->{isRestrictedAction}{'menu'}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('MENU_RESTRICTED');
  } else {
    my $menu = $this->{menu};
    my $header = $this->{menu_header};
    my $footer = $this->{menu_footer};
    $menu = Foswiki::Func::expandTemplate('MENU_FORMAT') unless defined $menu;
    $header = Foswiki::Func::expandTemplate('MENU_HEADER') unless defined $header;
    $footer = Foswiki::Func::expandTemplate('MENU_FOOTER') unless defined $footer;
    $result = $header . $menu . $footer;
  }

  my $label = $this->getLabelForAction("MENU", $mode);
  $result =~ s/\$label/$label/g;

  return $this->formatResult($result, "long");
}

###############################################################################
sub getPdfUrl {
  my $this = shift;

  my $url;
  my $context = Foswiki::Func::getContext();
  if ($context->{GenPDFPrincePluginEnabled} || 
      $context->{GenPDFOfficePluginEnabled} ||
      $context->{GenPDFWebkitPluginEnabled} || 
      $context->{GenPDFWeasyPluginEnabled}) {
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      'view',
      undef, undef,
      'contenttype' => 'application/pdf',
      'cover' => 'print',
    );
  } else {

    # SMELL: can't check for GenPDFAddOn reliably; we'd like to
    # default to normal printing if no other print helper is installed
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('genpdf', undef, undef, 'cover' => 'print',);
  }

  my $extraParams = Foswiki::Plugins::NatSkinPlugin::Utils::makeParams();
  $url .= ';' . $extraParams if $extraParams;

  return $url;
}

###############################################################################
sub getLabelForAction {
  my ($this, $action, $mode) = @_;

  my $label = Foswiki::Func::expandTemplate($action . "_" . uc($mode));
  $label = Foswiki::Func::expandTemplate($action) unless $label;

  return $label;
}

###############################################################################
sub renderEditForm {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  my ($topicObj) = Foswiki::Func::readTopic($this->{baseWeb}, $this->{baseTopic});
  if ($topicObj && $topicObj->getFormName) {
    if ($this->{isRestrictedAction}{'edit_form'}) {
      return '' if $this->{hiderestricted};
      $result = Foswiki::Func::expandTemplate("EDIT_FORM_ACTION_RESTRICTED");
    } else {
      $result = Foswiki::Func::expandTemplate("EDIT_FORM_ACTION");
    }
  }

  my $label = $this->getLabelForAction("EDIT_FORM", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderAccount {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $wikiName = Foswiki::Func::getWikiName();

  if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
  } else {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
  }

  my $label = $this->getLabelForAction("ACCOUNT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getHelpUrl {
  my $this = shift;

  my $helpTopic = $this->{help} || "UsersGuide";
  my $helpWeb = $Foswiki::cfg{SystemWebName};

  ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($helpWeb, $helpTopic);

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $helpWeb, $helpTopic);
}

###############################################################################
sub renderFirst {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  if ($this->{isRestrictedAction}{'first'} || $this->getCurRev() <= $this->getNrRev()) {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
  } else {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION');
  }

  my $label = $this->getLabelForAction("FIRST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getFirstUrl {
  my $this = shift;

  if ($this->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev' => 1);
  } else {
    my $request = Foswiki::Func::getCgiQuery();
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => (1 + $this->getNrRev()),
      'rev2' => 1,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

###############################################################################
sub renderLogin {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  my $loginUrl = $this->getLoginUrl();
  if ($loginUrl) {
    if ($this->{isRestrictedAction}{'login'}) {
      return '' if $this->{hiderestricted};
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION');
    }
  }

  my $label = $this->getLabelForAction("LOG_IN", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLoginManager {
  my $this = shift;

  return $this->{session}{loginManager} ||    # TMwiki-4.2
    $this->{session}{users}->{loginManager} ||    # TMwiki-4.???
    $this->{session}{client} ||                   # TMwiki-4.0
    $this->{session}{users}->{loginManager};      # Foswiki
}

###############################################################################
sub getLoginUrl {
  my $this = shift;

  return '' unless $this->{session};

  my $loginManager = $this->getLoginManager();
  return '' unless $loginManager;
  return $loginManager->loginUrl();
}

###############################################################################
sub renderLogout {
  my ($this, $sep, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  $sep ||= '';

  my $logoutUrl = $this->getLogoutUrl();
  if ($logoutUrl) {
    if ($this->{isRestrictedAction}{'logout'}) {
      return '' if $this->{hiderestricted};
      $result = $sep . Foswiki::Func::expandTemplate('LOG_OUT_ACTION_RESTRICTED');
    } else {
      $result = $sep . Foswiki::Func::expandTemplate('LOG_OUT_ACTION');
    }
  }

  my $label = $this->getLabelForAction("LOG_OUT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLogoutUrl {
  my $this = shift;

  my $loginManager = $this->getLoginManager();
  return '' unless $loginManager;

  # SMELL: I'd like to do this
  if ($loginManager->can("logoutUrl")) {
    return $loginManager->logoutUrl();
  }

  # but for now the "best" we can do is this
  if ($loginManager =~ /ApacheLogin/) {
    return '';
  }

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, logout => 1);
}

###############################################################################
sub getRegisterUrl {
  my $this = shift;

  my $loginManager = $this->getLoginManager();
  return '' unless $loginManager;

  # SMELL: I'd like to do this
  if ($loginManager->can("registerUrl")) {
    return $loginManager->registerUrl();
  }

  # but for now the "best" we can do is this:
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $Foswiki::cfg{SystemWebName}, 'UserRegistration');
}

###############################################################################
sub renderLast {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result =
    ($this->{isRestrictedAction}{'last'} || $this->getCurRev() >= $this->getMaxRev() - $this->getNrRev())
    ? Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('LAST_ACTION');

  my $label = $this->getLabelForAction("LAST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLastUrl {
  my $this = shift;

  if ($this->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev' => $this->getMaxRev());
  } else {
    my $rev2 = $this->getMaxRev() - $this->getNrRev();
    $rev2 = 1 if $rev2 < 1;
    my $request = Foswiki::Func::getCgiQuery();

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => $this->getMaxRev(),
      'rev2' => $rev2,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

###############################################################################
sub renderNext {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result =
    ($this->{isRestrictedAction}{'next'} || $this->getNextRev() > $this->getMaxRev() - $this->getNrRev())
    ? Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('NEXT_ACTION');

  my $label = $this->getLabelForAction("NEXT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getNextUrl {
  my $this = shift;

  my $request = Foswiki::Func::getCgiQuery();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($this->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev' => $this->getRev() + $this->getNrRev());
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => $this->getNextRev(),
      'rev2' => $this->getCurRev(),
      'context' => $context,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

###############################################################################
sub renderPrev {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result =
    ($this->{isRestrictedAction}{'prev'} || $this->getCurRev() <= $this->getNrRev())
    ? Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('PREV_ACTION');

  my $label = $this->getLabelForAction("PREV", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getPrevUrl {
  my $this = shift;

  my $request = Foswiki::Func::getCgiQuery();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($this->{action} eq 'view') {
    my $rev = $this->getRev() - $this->getNrRev();
    $rev = 1 if $rev < 1;
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev' => $rev);
  } else {

    my $rev2 = $this->getPrevRev() - $this->getNrRev();
    $rev2 = 1 if $rev2 < 1;

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => $this->getPrevRev(),
      'rev2' => $rev2,
      'context' => $context,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

###############################################################################
sub renderDiff {
  my ($this, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  if ($this->{isRestrictedAction}{'diff'}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
  } else {
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION');
  }

  my $label = $this->getLabelForAction("DIFF", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getDiffUrl {
  my $this = shift;

  my $rev2 = $this->getCurRev() - $this->getNrRev();
  $rev2 = 1 if $rev2 < 1;

  my $action = $this->{action};
  my $context = Foswiki::Func::getContext();
  if ($action !~ /^(compare|rdiff|diff)$/) {
    $action = $context->{DiffPluginEnabled} ? "diff": $context->{CompareRevisionsAddonPluginEnabled} ? "compare" : "rdiff";
  }
  my $request = Foswiki::Func::getCgiQuery();

  if ($context->{DiffPluginEnabled}) {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("diff");
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $action, undef, undef,
      'rev1' => $this->getCurRev(),
      'rev2' => $rev2,
      'context' => 2,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }

}

###############################################################################
sub getMaxRev {
  my $this = shift;

  unless (defined $this->{maxRev}) {
    $this->{maxRev} = Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision();
  }

  return $this->{maxRev};
}

###############################################################################
sub getCurRev {
  my $this = shift;

  unless (defined $this->{curRev}) {
    $this->{curRev} =
         Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision()
      || $this->getMaxRev()
      || 1;
  }

  return $this->{curRev};
}

###############################################################################
sub getRev {
  my $this = shift;

  unless (defined $this->{rev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev = $request->param('rev');
      my $rev1 = $request->param('rev1');
      my $rev2 = $request->param('rev2');

      if (defined($rev)) {
        $rev =~ s/[^\d]//g;
        $this->{rev} = $rev;
      } elsif (!defined($rev1) && !defined($rev2)) {
        $this->{rev} = $this->getCurRev();
      } else {
        $rev1 ||= 1;
        $rev2 ||= 1;
        $rev1 =~ s/[^\d]//g;
        $rev2 =~ s/[^\d]//g;
        $this->{rev} = $rev1 > $rev2 ? $rev1 : $rev2;
      }
    }

  }

  return $this->{rev};
}

###############################################################################
sub getNrRev {
  my $this = shift;

  unless (defined $this->{nrRev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev1 = $request->param('rev1') || 1;
      my $rev2 = $request->param('rev2') || 1;
      $rev1 =~ s/[^\d]//g;
      $rev2 =~ s/[^\d]//g;
      $this->{nrRev} = abs($rev1 - $rev2);
    }
    #$this->{nrRev} = $Foswiki::cfg{NumberOfRevisions} unless $this->{nrRev};
    $this->{nrRev} = 1 unless $this->{nrRev};
  }

  return $this->{nrRev};
}

###############################################################################
sub getPrevRev {
  my $this = shift;

  unless (defined $this->{prevRev}) {
    $this->{prevRev} = $this->getCurRev() - $this->getNrRev();
    $this->{prevRev} = 1 if $this->{prevRev} < 1;
  }

  return $this->{prevRev};
}

###############################################################################
sub getNextRev {
  my $this = shift;

  unless (defined $this->{nextRev}) {
    $this->{nextRev} = $this->getCurRev() + $this->getNrRev();
  }

  return $this->{nextRev};
}

1;
