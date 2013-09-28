package R2E::DB::Result::Feed;
use Moose;

extends qw/DBIx::Class::Core/;

__PACKAGE__->table('feed');

__PACKAGE__->add_columns(
    feed_id => {
	data_type   => 'integer',
	size        => 16,
	is_nullable => 0,
	is_auto_increment => 1,
    },
    title => {
	data_type   => 'varchar',
	size        => '128',
	is_nullable => 0,
    },
    category_id => {
	data_type   => 'integer',
	size        => 16,
	is_nullable => 0,
    },
    url => {
	data_type   => 'varchar',
	size        => '512',
	is_nullable => 0,
    },
    fetch_linked => {
	data_type   => 'bool',
	default     => 0,
	is_nullable => 0,
    },
    start_pattern => {
	data_type   => 'varchar',
	size        => 256,
	is_nullable => 1,
    },
    stop_pattern => {
	data_type   => 'varchar',
	size        => 256,
	is_nullable => 1,
    },
    last_checked => {
	data_type   => 'datetime',
	is_nullable => 1,
    },
    );

__PACKAGE__->set_primary_key('feed_id');

# allows me to call $feed->articles to get all articles
__PACKAGE__->has_many('articles' => 'R2E::DB::Result::Article', 'feed_id');

# will this let me call $feed->unseen_articles to get the unseen articles?
# I think so.
__PACKAGE__->has_many('unseen_articles' => 'R2E::DB::Result::Article',
		      ( { 'foreign.feed_id' => 'self.feed_id' },
			{ 'where' => [
			      { 'seen' =>  0 },
			      { 'seen' => undef }
			      ]
			}
		      )
    );

__PACKAGE__->has_many('seen_articles' => 'R2E::DB::Result::Article',
		      ( { 'foreign.feed_id' => 'self.feed_id' },
			{ 'where' => { 'article.seen' =>  1 } }
		      )
    );

# allows me to call $article->category to get the category object
__PACKAGE__->belongs_to('category' => 'R2E::DB::Result::Category', 'category_id');

1;
