# AncestryJoins
This gem provides additional ActiveRecord scopes to fetch ancestry records in
bulk.

## Problem
The ancestry gem only provides instance scopes which when used in
iteration causes N+1 query performance issues.
For example:

```ruby
# if we have 100 interesting items, this will run 1 + 100 querys!
Item.where(interesting: true).flat_map{|i| i.ancestors}
```

## Solution

Using this gem will fetch identical results to the `flat_map` but in a single
query.

```ruby
Item.where(interesting: true).with_ancestors_only
```

## Caveats

Do to the querying method, only Postgres is supported at the moment.
More databases can be supported in the future. Look at `lib/ancestry_joins.rb` 
to implement scopes for another database.

## Usage

**IMPORTANT** Use the scope *last* in the chain for good performance, otherwise
the ancestry grouping act on the entire table before applying the filter.
If you have other models to join against the ancestry, those maybe added after
including the ancestry joins.

```ruby
class Item < ActiveRecord::Base
  has_ancestry
  include AncestryJoins

  has_many :widgets
end

# Get list of Items with red color, their parents regardless of color, and the
# red items or red items ancestors' parents widgets are blue.
Item
  .where(color: 'red')
  .with_ancestors
  .joins(:widgets)
  .merge(Widget.where(color: 'blue'))
```

Look to the specs for more details.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ancestry_joins'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ancestry_joins

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ddrscott/ancestry_joins.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

