package R2E::CLI::send_updates;
use MooseX::App::Command;
use MooseX::Method::Signatures;

extends qw(R2E::CLI);

command_short_description "Send updates";
command_long_description <<"LONG";
Fetch new artcles and send the updates to the specified address.
LONG
    ;

use R2E;
use R2E::DB;
use Email::Stuffer;
use DateTime;
use DateTime::Format::RSS;
use DateTime::Format::Mail;

use feature 'unicode_strings'; 
use open ':encoding(utf8)'; 
use encoding 'utf8';

option to => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => 'Address to send to',
    );

option msmtp_profile => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => 'msmtp profile to use to send',
    );

option tag_subject => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Put a tag in the subject',
    );

option feeds => (
    is            => 'rw',
    isa           => 'Str',
    documentation => 'Feeds to check (pattern)',
    );

method run () {
    my $db  = R2E::DB->connect($self->dsn);
    my $r2e = R2E->new(db => $db);
    $r2e->debug(1) if $self->debug;

    my $feeds;
    if ($self->feeds) {
	$feeds = $r2e->fetch_feeds(title => $self->feeds);
    }
    else {
	$feeds = $r2e->fetch_feeds();
    }

    warn "# Feeds: ", $feeds->count if $self->debug;
    
    # Ooo. Thread safety could be an issue. Wait on this.
    #my $pfm = Parallel::ForkManager->new($self->concurrent);

    while (my $feed = $feeds->next) {
	my $articles = $feed->unseen_articles;
	if ($self->debug) {
	    warn "# Articles: ", $articles->count;
	}
	while (my $article = $articles->next) {
	    ## create message
	    #warn $r2e->cache->get('clean-'.$article->link) if $self->debug;

	    my $text_body = sprintf("Title: %s\nDate: %s\nLink: %s",
				    $article->title,
				    $article->date,
				    $article->link,
		);

	    my $email = Email::Stuffer
		->from("rsstoemail <".$self->to.">")
		->to($self->to)
		->header('X-Mailer' => "rsstoemail/$R2E::VERSION")
		->header('X-r2e-category' => $feed->category->name)
		->header('Xref' => $article->link)
		->text_body($text_body)
		->html_body($r2e->cache->get('clean-'.$article->link))
			    ;

	    my $date_dt = DateTime::Format::RSS->parse_datetime($article->date);
	    $date_dt->set_time_zone($r2e->time_zone);
	    if ($date_dt) {
		$email->header('Date', DateTime::Format::Mail->format_datetime( $date_dt ));
	    }

	    if ($self->tag_subject) {
		my $subject = sprintf(
		    '[r2e-%s] %s',
		    $feed->category->name,
		    $article->title
		    );
		$email->subject($subject)
	    }
	    else {
		$email->subject($article->title);
	    }

	    # warn "after email" if $self->debug;

	    ## send message
	    if ($self->debug) {
		#print STDERR $email->as_string;
	    }

	    my $command = sprintf("msmtp --account=%s %s",
				  $self->msmtp_profile,
				  $self->to);

	    open (my $SENDMAIL, '|-:encoding(utf8)', $command)
		or die "Can't open msmtp for sending: $!\n";
	    print $SENDMAIL $email->as_string;
	    close $SENDMAIL;

	    ## mark article as seen
	    $article->seen(1);
	    $article->update;
	}
    }
}

1;
