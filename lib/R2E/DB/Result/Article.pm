package R2E::DB::Result::Article;
use warnings;
use strict;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/ Ordered /);
__PACKAGE__->position_column('date');

__PACKAGE__->table('article');

__PACKAGE__->add_columns(
    feed_id => {
	data_type   => 'integer',
	size        => 16,
	is_nullable => 0,
    },
    identifier => {
	data_type   => 'varchar',
	size        => '256',
	is_nullable => 0,
    },
    date => {
	data_type   => 'datetime',
	is_nullable => 0,
    },
    title => {
	data_type   => 'varchar',
	size        => 256,
	is_nullable => 0,
    },
    link => {
	data_type   => 'varchar',
	size        => 512,
	is_nullable => 0,
    },
    seen => {
	data_type   => 'bool',
	size        => 2,
	default     => 0,
	is_nullable => 1,
    }
    );

# It's possible that two articles could have the same identifier but
# they should be unique per feed.
__PACKAGE__->set_primary_key( qw/ feed_id identifier / );

# allows me to call $article->feed to get the feed object
__PACKAGE__->belongs_to('feed' => 'R2E::DB::Result::Feed', 'feed_id');

1;
