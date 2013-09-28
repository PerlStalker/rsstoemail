#!/usr/bin/env perl
use warnings;
use strict;

use Test::Most;

use FindBin;
use lib "$FindBin::Bin/../lib";

use R2E;

my $r2e = R2E->new(debug => 1);
$r2e->cache->clear;

my $content;
lives_ok { $content = $r2e->_fetch_url(
	       url => 'http://www.google.com/',
	       key => 'google') } 'fetch google';
ok (defined ($content), "stuff came back");

done_testing();
