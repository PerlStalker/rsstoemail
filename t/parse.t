#!/usr/bin/env perl
use warnings;
use strict;

use Test::Most;

use FindBin;
use lib "$FindBin::Bin/../lib";

use R2E;

my $r2e = R2E->new(debug => 1);

my $data_dir = "$FindBin::Bin/data";

my $fh;
my $feed;
my $content;

open ($fh, "$data_dir/ace.rdf")
    or die "Can't open ace.rdf: $!";
$content = do { local $/; <$fh> }; # slurp
# explain $content;
$feed = $r2e->_parse_feed(feed_content => $content);
close $fh;

is $feed->item_count, 15, "Ace has 15 items";

#explain $feed;

is ${ $feed->items }[0]->title, 'Terror Attack in Nairobi Mall Kills At Least 25', 'Ace 0 title matches';
is ${ $feed->items }[0]->identifier, 'http://minx.cc/?post=343571', 'Ace 0 identifier matches';
is ${ $feed->items }[0]->link, 'http://minx.cc/?post=343571', 'Ace 0 link matches';
is ${ $feed->items }[0]->content,
    'Horrifyng. Al Shahhab claimed guilt. via @BrentCochran1...',
    'Ace 0 content matches';

$content = $r2e->slurp_file("$data_dir/ace0.html");

my $body = $r2e->_parse_article(
    article_source => $content,
    start_pattern  => "<div class=\"blog\">",
    stop_pattern   => "<div id=\"ace_comments\">"
);
explain $body;

my $cleaned = $r2e->tidy->clean($body);
explain $cleaned;

my $body = $r2e->_parse_article(
    article_source => $content,
);
explain $body;

my $cleaned = $r2e->tidy->clean($body);
explain $cleaned;

done_testing();
