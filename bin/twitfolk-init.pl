#!/usr/bin/perl

use warnings;
use strict;
use FindBin;
use Daemon::Control;

my $bin = "$FindBin::Bin/..";
 
Daemon::Control->new({
    name        => "TwitFolk",
    path        => $bin . '/bin/twitfolk-init.pl',
    program     => $bin . '/bin/twitfolk.pl',
    pid_file    => $bin . '/var/twitfolk.pid',
    stderr_file => $bin . '/var/twitfolk.out',
    stdout_file => $bin . '/var/twitfolk.out',
    fork        => 2,
})->run;
