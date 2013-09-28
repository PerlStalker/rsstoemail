package R2E::DB::Result::Category;
use Moose;

extends qw/DBIx::Class::Core/;

__PACKAGE__->table('category');

__PACKAGE__->add_columns(
    category_id => {
	data_type   => 'integer',
	size        => 16,
	is_nullable => 0,
	is_auto_increment => 1,
    },
    name => {
	data_type   => 'varchar',
	size        => 128,
	is_nullable => 0,
    },
    );

__PACKAGE__->set_primary_key('category_id');

__PACKAGE__->has_many('feeds' => 'R2E::DB::Result::Feed', 'category_id');

1;
