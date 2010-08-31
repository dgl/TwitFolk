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

use Cwd;
use TwitFolk;

my $twitfolk = TwitFolk->new_with_options(basedir => cwd);
my $command = $twitfolk->extra_argv->[0] || "start";
$twitfolk->$command;

warn $twitfolk->status_message if $twitfolk->status_message;
exit $twitfolk->exit_code;
