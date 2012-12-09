#!/usr/bin/perl

# vim:set sw=4 cindent:

=pod

TwitFolk

Gate tweets from your Twitter/identi.ca friends into an IRC channel.

http://dev.bitfolk.com/twitfolk/

Copyright ©2008 Andy Smith <andy+twitfolk.pl@bitfolk.com>

Artistic license same as Perl.

$Id: twitfolk.pl 1580 2010-06-10 12:45:21Z andy $
=cut

use warnings;
use strict;
use Config;
use FindBin;
use lib "lib", map "twitfolk-libs/lib/perl5/$_", "", $Config{archname};

BEGIN {
  chdir "$FindBin::Bin/..";
}

use TwitFolk;

my $twitfolk = TwitFolk->new_with_options;

$SIG{HUP} = sub {
  $twitfolk->handle_sighup;
};

$SIG{TERM} = $SIG{INT} = sub {
  $twitfolk->shutdown;
  exit 0;
};

$twitfolk->start;
