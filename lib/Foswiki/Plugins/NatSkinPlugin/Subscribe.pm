# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2013-2025 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::Subscribe;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::Subscribe

service class for email subscriptions

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Contrib::MailerContrib ();
use Error qw (:try);

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

sub render {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $webTopic = $params->{topic} || $theTopic;
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $webTopic);
  my $who = $params->{_DEFAULT} || $params->{who} || Foswiki::Func::getWikiName();

  my $then = $params->{then} // 1;
  my $else = $params->{else} // 0;

  return Foswiki::Contrib::MailerContrib::isSubscribedTo($web, $who, $topic) ? $then : $else;
}

sub jsonRpcSubscribe {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $user = Foswiki::Func::getWikiName();

  throw Error::Simple($this->{session}->i18n->maketext("Topic does not exist")) 
    unless Foswiki::Func::topicExists($web, $topic);

  throw Error::Simple($this->{session}->i18n->maketext("Bad subscriber"))
    if $user eq $Foswiki::cfg{DefaultUserWikiName};

  my $sub = $request->param("subscription") || $topic;
  ($web, $sub) = Foswiki::Func::normalizeWebTopicName($web, $sub) if $sub ne '*';

  Foswiki::Contrib::MailerContrib::changeSubscription($web, $user, $sub);

  my $result;
  if ($sub eq '*') {
    $result = $this->{session}->i18n->maketext('You have been subscribed to [_1].', $web);
  } else {
    $result = $this->{session}->i18n->maketext('You have been subscribed to [_1] in [_2].', $sub, $web);
  }

  return $result;
}

sub jsonRpcUnsubscribe {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $user = Foswiki::Func::getWikiName();

  throw Error::Simple($this->{session}->i18n->maketext("Topic does not exist")) 
    unless Foswiki::Func::topicExists($web, $topic);

  throw Error::Simple($this->{session}->i18n->maketext("Bad subscriber"))
    if $user eq $Foswiki::cfg{DefaultUserWikiName};

  my $sub = $request->param("subscription") || $topic;
  ($web, $sub) = Foswiki::Func::normalizeWebTopicName($web, $sub) if $sub ne '*';

  Foswiki::Contrib::MailerContrib::changeSubscription($web, $user, $sub, "-");

  my $result;
  if ($sub eq '*') {
    $result = $this->{session}->i18n->maketext('You have been unsubscribed from [_1].', $web);
  } else {
    $result = $this->{session}->i18n->maketext('You have been unsubscribed from [_1] in [_2].', $sub, $web);
  }

  return $result;
}

1;
