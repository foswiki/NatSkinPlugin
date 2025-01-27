# NatSeinPlugin.pm - Plugin handler for the NatSkin.
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

package Foswiki::Plugins::NatSkinPlugin::UserActions;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::UserActions

implements the %USERACTIONS macro

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();
use Foswiki::Plugins::NatSkinPlugin::Utils qw(:all);

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

=begin TML

---++ init($params, $web, $topic) -> $this

initializor for this module; init is called every time %USERACTIONS is rendered

=cut

sub init {
  my ($this, $params, $web, $topic) = @_;

  $this->{topic} = $topic;
  $this->{web} = $web;
  $this->{baseTopic} = $this->{session}{topicName};
  $this->{baseWeb} = $this->{session}{webName};
  $this->{usermenu} = $params->{usermenu};
  $this->{menu} = $params->{menu};
  $this->{menu_header} = $params->{menu_header};
  $this->{menu_footer} = $params->{menu_footer};
  $this->{hiderestricted} = Foswiki::Func::isTrue($params->{hiderestricted}, 0);
  $this->{mode} = $params->{mode} || 'short';
  $this->{sep} = $params->{sep} || $params->{separator} || '';
  $this->{unique} = Foswiki::Func::isTrue($params->{unique}, 1);

  my $context = Foswiki::Func::getContext();

  # get restrictions
  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'attach,delete,archive,diff,edit,harvest,managetags,more,move,raw,restore'
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
  $this->{isRestrictedAction}{subscribe} = 1 unless $context->{authenticated};

  # list all actions that need edit rights
  if ($this->{isRestrictedAction}{edit}) {
    $this->{isRestrictedAction}{attach} = 1;
    $this->{isRestrictedAction}{delete} = 1;
    $this->{isRestrictedAction}{archive} = 1;
    $this->{isRestrictedAction}{edit_form} = 1;
    $this->{isRestrictedAction}{edit_raw} = 1;
    $this->{isRestrictedAction}{edit_settings} = 1;
    $this->{isRestrictedAction}{edit_text} = 1;
    $this->{isRestrictedAction}{harvest} = 1;
    $this->{isRestrictedAction}{move} = 1;
    $this->{isRestrictedAction}{restore} = 1;
  }

  # if you've got access to this topic then all actions are allowed
  $this->{wikiName} = Foswiki::Func::getWikiName();
  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});

  my $gotWebAccess = Foswiki::Func::checkAccessPermission('CHANGE', $this->{wikiName}, undef, undef, $this->{baseWeb});
  
  $this->{isRestrictedAction} = () if $gotAccess;
  $this->{isRestrictedAction}{new} = 1 unless $gotWebAccess;

  # these topics can never be moved
  if ($topic =~ /^(WebHome|WebPreferences|SitePreferences)$/) {
    $this->{isRestrictedAction}{move} = 1;
    $this->{isRestrictedAction}{delete} = 1;
    $this->{isRestrictedAction}{archive} = 1;
  }

  my $request = Foswiki::Func::getRequestObject();
  $this->{isRaw} = ($request) ? $request->param('raw') : '';

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
  $this->{isHistory} = ($themeEngine->{skinState}{history})?1:0;

  my $isCompare = ($themeEngine->{skinState}{action} eq 'compare') ? 1 : 0;
  my $isRdiff = ($themeEngine->{skinState}{action} eq 'rdiff') ? 1 : 0;
  my $isDiff = ($themeEngine->{skinState}{action} eq 'diff') ? 1 : 0;
  $this->{action} = 'view';
  $this->{action} = 'compare' if $isCompare;
  $this->{action} = 'rdiff' if $isRdiff;
  $this->{action} = 'diff' if $isDiff;

  # disable registration
  unless ($context->{registration_enabled}) {
    $this->{isRestrictedAction}{register} = 1;
  }

  # disable changePassword
  unless ($context->{passwords_modifyable}) {
    $this->{isRestrictedAction}{changepassword} = 1;
    $this->{isRestrictedAction}{changeemail} = 1;
  }

  # user admin tools
  unless ($context->{isadmin} && getFormName($this->{baseWeb}, $this->{baseTopic}) =~ /.*User(Form|Topic)$/) {
    $this->{isRestrictedAction}{removeuser} = 1;
  }

  # diff, history, restore
  unless (getMaxRevision() > 1) {
    $this->{isRestrictedAction}{diff} = 1;
    $this->{isRestrictedAction}{restore} = 1;
  }

  return $this;
}

=begin TML

---++ render($params, $topic, $web) -> $html

this is the entry method for this module's main feature

=cut

sub render {
  my ($this, $params, $topic, $web) = @_;

  $this->init($params, $web, $topic);

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

=begin TML
 
---++ formatResult($text, $mode) -> $html

formats the result of the %USERACTIONS macro

   * $text: the format string 
   * $mode: short/long decides on the verbosity of the actions' lable string

=cut

sub formatResult {
  my ($this, $text, $mode) = @_;

  $mode ||= $this->{mode} || 'short';

  # special actions
  $text =~ s/\$(?:usermenu\b|action\(usermenu(?:,\s*(.*?))?\))/$this->renderUserMenu($1, $mode)/ge;
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

  # special actions
  $text =~ s/\$action\(archive(?:,\s*(.*?))?\)/$this->renderArchive($1, $mode)/ge;

  # generic actions
  $text =~ s/\$action\((.*?)(?:,\s*(.*?))?\)/$this->renderAction($1, undef, undef, $2, $mode)/ge;

  $text =~ s/\$(?:menu\b|action\(menu(?:,\s*(.*?))?\))/$this->renderMenu($1, $mode)/ge;

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
  $text =~ s/\$rev\b/$this->getRev()/ge;
  $text =~ s/\$prevrev\b/$this->getPrevRev()/ge;
  $text =~ s/\$maxrev\b/getMaxRevision()/ge;

  $mode = uc($mode);
  $text =~ s/\$mode\b/$mode/g;

  return $text;
}

=begin TML

---++ renderAction($action, $template, $restrictedTemplate, $context, $mode) -> html

TODO

=cut

sub renderAction {
  my ($this, $action, $template, $restrictedTemplate, $context, $mode) = @_;

  #print STDERR "called renderAction($action)\n";

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{$action};
  $this->{seen}{$action} = 1;

  return '' 
    if $action =~ /^(history|contributors)$/ &&
      ($Foswiki::cfg{FeatureAccess}{AllowHistory} // '') eq 'acl' &&
      !Foswiki::Func::checkAccessPermission('HISTORY', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});

  return '' 
    if $action =~ /^raw/ &&
      ($Foswiki::cfg{FeatureAccess}{AllowRaw} // '') eq 'acl' &&
      !Foswiki::Func::checkAccessPermission('CHANGE', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb}) &&
      !Foswiki::Func::checkAccessPermission('RAW', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});

  return ''
    if $action eq 'changeadmin' &&
    !Foswiki::Func::checkAccessPermission('CHANGE', $this->{wikiName}, undef, "AdminGroup", $Foswiki::cfg{UsersWebName});

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

=begin TML

---++ renderEdit($context, $mode) -> $html

renders the =$edit= action

=cut

sub renderEdit {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{edit};
  $this->{seen}{edit} = 1;

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{edit}) {
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

=begin TML

---++ renderEditRaw($context, $mode) -> $html

renders the =$edit_raw= action

=cut

sub renderEditRaw {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{edit_raw};
  $this->{seen}{edit_raw} = 1;

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{edit_raw}) {
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

=begin TML

---++ renderView($context, $mode) -> $html

renders the =$view= action

=cut

sub renderView {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{view};
  $this->{seen}{view} = 1;

  my $result = '';

  if ($this->{isRestrictedAction}{view}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
  } else {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
    if ($themeEngine->{skinState}{action} eq 'view') {
      return '';
    } else {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
    }
  }

  my $label = $this->getLabelForAction("VIEW", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getEditUrl() -> $url

returns the edit url

=cut

sub getEditUrl {
  my $this = shift;

  return getScriptUrlPath(
    "edit", undef, undef, 
    't' => time()
  );
}

=begin TML

---++ getRestoreUrl() -> $url

returns the restore url

=cut

sub getRestoreUrl {
  my $this = shift;

  my $request = Foswiki::Func::getRequestObject();
  my $rev = $request->param('rev');
  $rev ||= ($this->getRev() - 1) || 1;

  return getScriptUrlPath(
    "rest", "NatSkinPlugin", "restore",
    'topic' => $this->{web}.".".$this->{topic},
    'rev' => $rev,
  );
}

=begin TML

---++ renderRaw($context, $mode) -> $html

renders the =$raw= action

=cut

sub renderRaw {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{raw};
  $this->{seen}{raw} = 1;

  return '' 
    if ($Foswiki::cfg{FeatureAccess}{AllowRaw} // '') eq 'acl' && 
    !Foswiki::Func::checkAccessPermission('CHANGE', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb}) &&
    !Foswiki::Func::checkAccessPermission('RAW', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});

  my $result = '';
  my $label;

  if ($this->{isRestrictedAction}{raw}) {
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

=begin TML

---++ renderMenu($context, $mode) -> $html

renders the =$menu= token

=cut

sub renderMenu {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  my $result = '';

  if ($this->{isRestrictedAction}{menu}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('MENU_RESTRICTED');
  } else {
    my $menu = $this->{menu} // Foswiki::Func::expandTemplate('MENU_FORMAT');
    my $header = $this->{menu_header} // Foswiki::Func::expandTemplate('MENU_HEADER');
    my $footer = $this->{menu_footer} // Foswiki::Func::expandTemplate('MENU_FOOTER');
    $result = $header . $menu . $footer;
  }

  my $label = $this->getLabelForAction("MENU", $mode);
  $result =~ s/\$label/$label/g;

  return $this->formatResult($result, "long");
}

=begin TML

---++ renderUserMenu($context, $mode) -> $html

renders the =$usermenu= token

=cut

sub renderUserMenu {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  my $result = '';

  if ($this->{isRestrictedAction}{usermenu}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('USERMENU_RESTRICTED');
  } else {
    $result = $this->{usermenu} // Foswiki::Func::expandTemplate('USERMENU_FORMAT');
  }

  return $this->formatResult($result, "long");
}

=begin TML

---++ getPdfUrl() -> $url

renders the =$pdf= token. will differ depending the plugins installed. supported plugins are

   * GenPDFPrincePluginEnabled
   * GenPDFOfficePluginEnabled
   * GenPDFWebkitPluginEnabled
   * GenPDFWeasyPluginEnabled

=cut

sub getPdfUrl {
  my $this = shift;

  my $url;
  my $context = Foswiki::Func::getContext();
  if ($context->{GenPDFPrincePluginEnabled} || 
      $context->{GenPDFOfficePluginEnabled} ||
      $context->{GenPDFWebkitPluginEnabled} || 
      $context->{GenPDFWeasyPluginEnabled}) {
    $url = getScriptUrlPath(
      'view',
      undef, undef,
      'contenttype' => 'application/pdf',
      'cover' => 'print',
    );
  } else {

    # SMELL: can't check for GenPDFAddOn reliably; we'd like to
    # default to normal printing if no other print helper is installed
    $url = getScriptUrlPath('genpdf', undef, undef, 'cover' => 'print',);
  }

  my $extraParams = makeParams();
  $url .= ';' . $extraParams if $extraParams;

  return $url;
}

=begin TML

---++ getLabelForAction($action, $mode) -> $string

returns the label for the given action and mode

=cut

sub getLabelForAction {
  my ($this, $action, $mode) = @_;

  my $label = Foswiki::Func::expandTemplate($action . "_" . uc($mode));
  $label = Foswiki::Func::expandTemplate($action) unless $label;

  return $label;
}

=begin TML

---++ renderEditForm($context, $mode) -> $html

renders the =$edit_form= token

=cut

sub renderEditForm {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{edit_form};
  $this->{seen}{edit_form} = 1;

  my $result = '';

  if (getFormName($this->{baseWeb}, $this->{baseTopic})) {
    if ($this->{isRestrictedAction}{edit_form}) {
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

=begin TML

---++ renderArchive($context, $mode) -> $html

renders the =$archive= token

=cut

sub renderArchive {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};
  return '' if $this->{unique} && $this->{seen}{archive};
  $this->{seen}{archive} = 1;

  my $archiveWeb = "$this->{web}.Archive";
  return '' unless Foswiki::Func::webExists($archiveWeb);

  my $result = '';

  if (Foswiki::Func::topicExists($archiveWeb, $this->{topic})) {
    $result = Foswiki::Func::expandTemplate('ARCHIVE_ACTION_RESTRICTED');
  } else {
    $result = Foswiki::Func::expandTemplate('ARCHIVE_ACTION');
  }

  my $label = $this->getLabelForAction("ARCHIVE", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ renderAccount($context, $mode) -> $html

renders the =$account= token

=cut

sub renderAccount {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{account};
  $this->{seen}{account} = 1;

  my $result = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};

  if (Foswiki::Func::topicExists($usersWeb, $this->{wikiName})) {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
  } else {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
  }

  my $label = $this->getLabelForAction("ACCOUNT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getHelpUrl() -> $url

returns the view url to the help page

=cut

sub getHelpUrl {
  my $this = shift;

  my $helpTopic = $this->{help} || "UsersGuide";
  my $helpWeb = $Foswiki::cfg{SystemWebName};

  ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($helpWeb, $helpTopic);

  return getScriptUrlPath('view', $helpWeb, $helpTopic);
}

=begin TML

---++ renderFirst($context, $mode) -> $html

renders the =$first= token

=cut

sub renderFirst {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{first};
  $this->{seen}{first} = 1;

  my $result = '';

  if ($this->{isRestrictedAction}{first} || $this->getCurRev() <= $this->getNrRev()) {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
  } else {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION');
  }

  my $label = $this->getLabelForAction("FIRST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getFirstUrl() -> $url

returns the url for a =$first= action

=cut

sub getFirstUrl {
  my $this = shift;

  if ($this->{action} eq 'view') {
    return getScriptUrlPath('view', undef, undef, 'rev' => 1);
  } else {
    my $request = Foswiki::Func::getRequestObject();
    return getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => (1 + $this->getNrRev()),
      'rev2' => 1,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

=begin TML

---++ renderLogin($context, $mode) -> $html

renders the $login token

=cut

sub renderLogin {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{login};
  $this->{seen}{login} = 1;

  my $result = '';

  my $loginUrl = $this->getLoginUrl();
  if ($loginUrl) {
    if ($this->{isRestrictedAction}{login}) {
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

=begin TML

---++ getLoginManager() -> $loginManager

compatibility layer to get the instance of the current login manager

=cut

sub getLoginManager {
  my $this = shift;

  return $this->{session}{loginManager} ||    # TMwiki-4.2
    $this->{session}{users}->{loginManager} ||    # TMwiki-4.???
    $this->{session}{client} ||                   # TMwiki-4.0
    $this->{session}{users}->{loginManager};      # Foswiki
}

=begin TML

---++ getLoginUrl() -> $url

returns the login url asking the login manager

=cut

sub getLoginUrl {
  my $this = shift;

  return '' unless $this->{session};

  my $loginManager = $this->getLoginManager();
  return '' unless $loginManager;
  return $loginManager->loginUrl();
}

=begin TML

---++ renderLogout($sep, $context, $mode) -> $html

renders the $logout token. unfortunately the login manager doesn't have
an api for this

=cut

sub renderLogout {
  my ($this, $sep, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{logout};
  $this->{seen}{logout} = 1;

  my $result = '';
  $sep ||= '';

  my $logoutUrl = $this->getLogoutUrl();
  if ($logoutUrl) {
    if ($this->{isRestrictedAction}{logout}) {
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

=begin TML

---++ getLogoutUrl() -> $url

returns the logout url

=cut

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

  return getScriptUrlPath('view', undef, undef, logout => 1);
}

=begin TML

---++ getRegisterUrl() -> $url

get the registration url

=cut

sub getRegisterUrl {
  my $this = shift;

  my $loginManager = $this->getLoginManager();
  return '' unless $loginManager;

  # SMELL: I'd like to do this
  if ($loginManager->can("registerUrl")) {
    return $loginManager->registerUrl();
  }

  # but for now the "best" we can do is this:
  return getScriptUrlPath('view', $Foswiki::cfg{SystemWebName}, 'UserRegistration');
}

=begin TML

---++ renderLast($context, $mode) -> $html

renders the $last token

=cut

sub renderLast {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{last};
  $this->{seen}{last} = 1;

  my $result =
    ($this->{isRestrictedAction}{last} || 
     $this->getCurRev() >= getMaxRevision()  - $this->getNrRev()
    )
    ? Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('LAST_ACTION');

  my $label = $this->getLabelForAction("LAST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getLastUrl() -> $url

returns the url used in the $last token

=cut

sub getLastUrl {
  my $this = shift;

  if ($this->{action} eq 'view') {
    return getScriptUrlPath('view', undef, undef, 'rev' => getMaxRevision());
  } else {
    my $rev2 = getMaxRevision() - $this->getNrRev();
    $rev2 = 1 if $rev2 < 1;
    my $request = Foswiki::Func::getRequestObject();

    return getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => getMaxRevision(),
      'rev2' => $rev2,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

=begin TML

---++ renderNext($context, $mode) -> $html

renders the =$next= token

=cut

sub renderNext {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{next};
  $this->{seen}{next} = 1;

  return '' 
      if ($Foswiki::cfg{FeatureAccess}{AllowHistory} // '') eq 'acl' &&
      !Foswiki::Func::checkAccessPermission('HISTORY', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});

  my $result =
    ($this->{isRestrictedAction}{next} || $this->getCurRev() >= getMaxRevision())
    ? Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('NEXT_ACTION');

  my $label = $this->getLabelForAction("NEXT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getNextUrl() -> $url

returns the url for the =$next= action

=cut

sub getNextUrl {
  my $this = shift;

  my $request = Foswiki::Func::getRequestObject();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($this->{action} eq 'view') {
    return getScriptUrlPath('view', undef, undef, 'rev' => $this->getRev() + $this->getNrRev());
  } else {
    return getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => $this->getNextRev(),
      'rev2' => $this->getCurRev(),
      'context' => $context,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

=begin TML

---++ renderPrev($context, $mode) -> $html

renders the =$prev= token

=cut

sub renderPrev {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{prev};
  $this->{seen}{prev} = 1;

  return '' 
      if ($Foswiki::cfg{FeatureAccess}{AllowHistory} // '') eq 'acl' &&
      !Foswiki::Func::checkAccessPermission('HISTORY', $this->{wikiName}, undef, $this->{baseTopic}, $this->{baseWeb});


  my $result =
    ($this->{isRestrictedAction}{prev} || $this->getCurRev() <= $this->getNrRev())
    ? Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED')
    : Foswiki::Func::expandTemplate('PREV_ACTION');

  my $label = $this->getLabelForAction("PREV", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getPrevUrl() -> $url

returns the url used in the =$prev= token

=cut

sub getPrevUrl {
  my $this = shift;

  my $request = Foswiki::Func::getRequestObject();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($this->{action} eq 'view') {
    my $rev = $this->getRev() - $this->getNrRev();
    $rev = 1 if $rev < 1;
    return getScriptUrlPath('view', undef, undef, 'rev' => $rev);
  } else {

    my $rev2 = $this->getPrevRev() - $this->getNrRev();
    $rev2 = 1 if $rev2 < 1;

    return getScriptUrlPath(
      $this->{action}, undef, undef,
      'rev1' => $this->getPrevRev(),
      'rev2' => $rev2,
      'context' => $context,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

=begin TML

---++ renderDiff($context, $mode) -> $html

renders the =$diff= token

=cut

sub renderDiff {
  my ($this, $context, $mode) = @_;

  return '' if defined($context) && !Foswiki::Func::getContext()->{$context};

  return '' if $this->{unique} && $this->{seen}{diff};
  $this->{seen}{diff} = 1;

  my $result = '';
  if ($this->{isRestrictedAction}{diff}) {
    return '' if $this->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
  } else {
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION');
  }

  my $label = $this->getLabelForAction("DIFF", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

=begin TML

---++ getDiffUrl() -> $url

returns the url used in the =$diff= token

=cut

sub getDiffUrl {
  my $this = shift;

  my $rev2 = $this->getCurRev() - $this->getNrRev();
  $rev2 = 1 if $rev2 < 1;

  my $action = $this->{action};
  my $context = Foswiki::Func::getContext();
  if ($action !~ /^(compare|rdiff|diff)$/) {
    $action = $context->{DiffPluginEnabled} ? "diff": $context->{CompareRevisionsAddonPluginEnabled} ? "compare" : "rdiff";
  }
  my $request = Foswiki::Func::getRequestObject();

  if ($context->{DiffPluginEnabled}) {
    return getScriptUrlPath("diff");
  } else {
    return getScriptUrlPath(
      $action, undef, undef,
      'rev1' => $this->getCurRev(),
      'rev2' => $rev2,
      'context' => 2,
      'render' => $request->param("render") || Foswiki::Func::getPreferencesValue("DIFFRENDERSTYLE") || '',
    );
  }
}

=begin TML

---++ getCurRev() -> $rev

returns the number of the current rev

=cut

sub getCurRev {
  my $this = shift;

  unless (defined $this->{curRev}) {
    $this->{curRev} = getCurRevision() || getMaxRevision() || 1;
  }

  return $this->{curRev};
}

=begin TML

---++ getRev() -> $rev

SMELL

=cut

sub getRev {
  my $this = shift;

  unless (defined $this->{rev}) {
    my $request = Foswiki::Func::getRequestObject();
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

=begin TML

---++ getNrRev() -> $rev

SMELL

=cut

sub getNrRev {
  my $this = shift;

  unless (defined $this->{nrRev}) {
    my $request = Foswiki::Func::getRequestObject();
    if ($request) {
      my $rev1 = $request->param('rev1') || 1;
      my $rev2 = $request->param('rev2') || 1;
      $rev1 =~ s/[^\d]//g;
      $rev2 =~ s/[^\d]//g;
      $this->{nrRev} = abs($rev1 - $rev2);
    }
    $this->{nrRev} = 1 unless $this->{nrRev};
  }

  return $this->{nrRev};
}

=begin TML

---++ getPrevRev() -> $rev

gets the previous rev counting down from the current rev

=cut

sub getPrevRev {
  my $this = shift;

  unless (defined $this->{prevRev}) {
    $this->{prevRev} = $this->getCurRev() - $this->getNrRev();
    $this->{prevRev} = 1 if $this->{prevRev} < 1;
  }

  return $this->{prevRev};
}

=begin TML

---++ getNextRev() -> $rev

gets the next rev counting up from the current rev

=cut

sub getNextRev {
  my $this = shift;

  unless (defined $this->{nextRev}) {
    $this->{nextRev} = $this->getCurRev() + $this->getNrRev();
  }

  return $this->{nextRev};
}

1;
