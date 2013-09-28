package R2E;
use warnings;
use strict;

use Moose;
use MooseX::Method::Signatures;

use feature 'unicode_strings';
use encoding 'utf8';

use FindBin;
use Cache::File;
use LWP;
use File::Path qw(make_path);
use XML::RAI;
use XML::FeedPP;
use HTML::Tidy;
use Try::Tiny;
use utf8;

use R2E::Cache::File;
use R2E::DB::Result::Feed;

our $VERSION = '0.01';

# TODO auto create based on global config
has db => (
    is       => 'rw',
    isa      => 'R2E::DB',
    );

# TODO allow other forms of caching
has cache => (
    is        => 'rw',
#    isa       => 'Cache::File',
    does      => 'R2E::Cache',
    lazy      => 1,
    builder   => '_build_cache',
    );

has ua =>    (
    is        => 'rw',
    isa       => 'LWP::UserAgent',
    lazy      => 1,
    builder   => '_build_ua',
    );

has rss_parser => (
    is        => 'rw',
    isa       => 'XML::RSS::Parser',
    lazy      => 1,
    builder   => '_build_rss_parser',
    );

has tidy => (
    is        => 'rw',
    isa       => 'HTML::Tidy',
    lazy      => 1,
    builder   => '_build_tidy',
    );

has verbose => (
    is        => 'rw',
    isa       => 'Bool',
    default   => 0,
    );

has debug => (
    is        => 'rw',
    isa       => 'Bool',
    default   => 0,
    );

has time_zone => (
    is            => 'rw',
    isa           => 'DateTime::TimeZone',
    lazy          => 1,
    builder       => '_build_time_zone',
    );

method _build_time_zone () {
    return DateTime::TimeZone->new(name => 'local'); # guess the time zone
}

# dies if file could not be fetched
# returns the content
method _fetch_url (
    Str :$url!,
    Str :$key?,
    DateTime::Duration :$expiry? # see Cache
    ) {

    $key = $url if not $key;

    my $content = $self->cache->get($key);

    if (not $content) {
	# download url
	print STDERR "Fetching $url from Net\n" if $self->debug;
	my $request = HTTP::Request->new(GET => $url);
	my $response = $self->ua->request($request);

	if ($response->is_success) {
	    # put the response into the cache
	    $content = $response->content;
	    $self->cache->set($key, $content, $expiry);
	}
	else {
	    die "Unable to fetch $url: ".$response->status_line."\n";
	}
    }
    return $content;
}

method purge_cache () {
    $self->cache->purge;
}

# Download all feeds (or fetch from the cache)
# Returns the feed list
method fetch_feeds (
    Str :$title
    ) {
    if (not defined $self->db) {
	die "No DB set!\n";
    }

    # $self->purge_cache;

    my $feeds;
    if ($title) {
	$feeds = $self->db->resultset('Feed')->search(
	    { title => { like => $title } }
	    );
    }
    else {
	$feeds = $self->db->resultset('Feed');
    }

    while (my $feed = $feeds->next) {
	## Try to parse the feed with XML::RAI first, then try XML::FeedPP

	# ::RAI is more consistent but sometimes has problems parsing
	# feeds.  ::FeedPP can usually parse the feeds the ::RAI fails
	# to parse but, sometimes, returns an object rather than an text
	# scalar for ->description().

	try {
	    $self->_fetch_feed_rai($feed);
	} catch {
	    try {
		$self->_fetch_feed_feedpp($feed);
	    } catch {
		warn "Can't parse feed: ", $feed->url, "\n";
	    };
	};
    }

    # need to reset so the caller can iterate through the feeds again.
    $feeds->reset;
    return $feeds;
}

method fetch_feeds2 (
    Str :$title
    ) {

    my $feeds;
    if ($title) {
	$feeds = $self->db->resultset('Feed')->search(
	    { title => { like => $title } }
	    );
    }
    else {
	$feeds = $self->db->resultset('Feed');
    }

  FEED: while (my $feed = $feeds->next) {
      my $content;
      my $parsed;

      try {
	  $content = $self->_fetch_url(url => $feed->url);
      } catch {
	  warn "Unable to fetch ".$feed->url.": \n";
	  next FEED;
      };

      next FEED if not $content;

      try { 
	  $parsed = XML::FeedPP->new($content, "-type" => 'string', utf8_flag => 1);
      } catch {
	  warn "Unable to parse feed ".$feed->title.": \n";
	  next FEED;
      };

      foreach my $article ($parsed->get_item()) {
	  my $opts = {
	      feed_id    => $feed->id,
	      identifier => $article->guid ? $article->guid : $article->link,
	      title      => $article->title,
	      date       => $article->pubDate,
	      link       => $article->link,
	  };
	  my $article_record = $self->db->resultset("Article")->find_or_create($opts);
	  next if $article_record->seen;

	  use Data::Dumper; print Dumper $article->description if $self->debug;

	  $self->_fetch_article(
	      article => $article_record,
	      content => $article->description ? $article->description : ''
	      );
      }
  }

    # need to reset so the caller can iterate through the feeds again.
    $feeds->reset;
    return $feeds;
}

# $article is a R2E::DB::Result::Article
method _fetch_article (
     :$article!,
    Str                      :$content
    ) {
    ## put article in cache
    # look for cleaned page in the cache
    my $article_content = $self->cache->get('clean-'.$article->link);

    my $feed = $article->feed;

    if (not $article_content) {
	if ($feed->fetch_linked) {
	    my $full_page;
	    try { 
		$full_page = $self->_fetch_url(url => $article->link);
	    } catch {
		warn "Unable to fetch ".$article->link."\n";
		return;
	    };
		    
	    if (not defined $full_page) {
		warn "Fetched article content is empty for ".$article->link;
		return;
	    }

	    if (defined $feed->start_pattern
		and defined $feed->stop_pattern
		) {
		$article_content = $self->_parse_article(
		    article_source => $full_page,
		    start_pattern  => $feed->start_pattern,
		    stop_pattern   => $feed->stop_pattern
		    );
	    }
	    else {
		$article_content = $self->_parse_article(
		    article_source => $full_page
		    );
	    }
	}
	else {
	    $article_content = $content;
	}
	
	$article_content = "<p>Source: ".$article->link."</p>".$article_content;

	my $cleaned = $self->_clean_article(
	    article_source => $article_content
	    );

	$self->cache->set('clean-'.$article->link, $cleaned #, "2 weeks"
	    );
    }
}

method _fetch_feed_rai (
    R2E::DB::Result::Feed $feed
    ) {
    ## fetch feed
    my $content;
    my $parsed;

    if ($self->debug or $self->verbose) {
	warn "Fetching ", $feed->title, " with ::RAI\n"
    }

    try {
	$content = $self->_fetch_url(url => $feed->url);
    } catch {
	warn "Unable to fetch ".$feed->url.": $_\n";
	return;
    };

    return if not $content;

    # print STDERR $content if $self->debug;
    
    try {
	$parsed = $self->_parse_feed(feed_content => $content);
    } catch {
	warn "Unable to parse feed ".$feed->title.": $_\n";
	return;
    };
    
    foreach my $article ( @{ $parsed->items } ) {
	## add feed to db
	my $opts = {
	    feed_id    => $feed->feed_id,
	    identifier => $article->identifier,
	    title      => $article->title,
	    date       => $article->created,
	    link       => $article->link,
	};
	my $article_record = $self->db->resultset("Article")->find_or_create($opts);
	next if $article_record->seen;

	$self->_fetch_article(
	    article => $article_record,
	    content => $article->content
	    );
    }
}

method _fetch_feed_feedpp (
    R2E::DB::Result::Feed $feed
    ) {
    ## fetch feed
    my $content;
    my $parsed;

    if ($self->debug or $self->verbose) {
	warn "Fetching ", $feed->title, " with ::FeedPP\n"
    }

    try {
	$content = $self->_fetch_url(url => $feed->url);
    } catch {
	warn "Unable to fetch ".$feed->url.": $_\n";
	return;
    };

    return if not $content;

    # print STDERR $content if $self->debug;
    
    try {
	$parsed = XML::FeedPP->new($content, "-type" => 'string', utf8_flag => 1);
	#use Data::Dumper; print STDERR Dumper $parsed;
    } catch {
	warn "Unable to parse feed ".$feed->title.": $_\n";
	return;
    };
    
    foreach my $article ($parsed->get_item()) {
	my $opts = {
	    feed_id    => $feed->id,
	    identifier => $article->guid ? $article->guid : $article->link,
	    title      => $article->title,
	    date       => $article->pubDate,
	    link       => $article->link,
	};
	my $article_record = $self->db->resultset("Article")->find_or_create($opts);
	next if $article_record->seen;

	# $article->content is sometimes not a scalar
	
	$self->_fetch_article(
	    article => $article_record,
	    content => $article->content
	    );
    }
}

method _parse_feed (
    Str :$feed_content
    ) {
    #my $feed = $self->rss_parser->parse_string($feed_content);
    my $feed = XML::RAI->parse($feed_content); 
   return $feed;
}

#
method _parse_article (
    Str :$article_source!,
    Str|Undef :$start_pattern = '<body.*?>',
    Str|Undef :$stop_pattern  = '</body>'
    ) {
    $start_pattern = '<body.*?>' unless $start_pattern;
    $stop_pattern  = '</body>'   unless $stop_pattern;

    my $body;
    if ($article_source =~ /$start_pattern(.*?)$stop_pattern/si) {
	$body = $1;
    } else {
	$body = $article_source;
    }
    return $body;
}

method _clean_article (
    Str :$article_source!
    ) {
    return $self->tidy->clean($article_source);
}

method slurp_fh ($fh) {
    return do { local $/, <$fh> };
}

method slurp_file ($file_name) {
    open my $fh, $file_name or die "Can't open $file_name: \n";
    my $content = $self->slurp_fh($fh);
    close $fh;

    return $content;
}

method _build_cache () {
    my $cache_root = "$FindBin::Bin/../var/cache/rsstoemail";

    if ($self->debug or $self->verbose) {
	make_path($cache_root, { mode => 0700, verbose => 1 });
    }
    else {
	make_path($cache_root, { mode => 0700 });
    }
    
    # my $cache = Cache::File->new(
    # 	cache_root      => $cache_root,
    # 	default_expires => "29 minutes"
    # 	);

    my $cache = R2E::Cache::File->new(
	cache_root => $cache_root,
	time_zone  => $self->time_zone,
	);

    return $cache;
}

method _build_ua () {
    my $ua = LWP::UserAgent->new;
    $ua->agent("rsstoemail/$VERSION");
    return $ua;
}

method _build_rss_parser () {
    #my $parser = XML::RAI->new;
    my $parser = XML::RSS::Parser->new;
    return $parser;
}

method _build_tidy () {
    return HTML::Tidy->new;
}

1;
