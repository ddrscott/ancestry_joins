require 'spec_helper'

begin
  ActiveRecord::Base.connection
rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    host: 'localhost',
    database: 'ancestry_joins_test'
  )
end

ActiveRecord::Schema.define do
  create_table :items, force: true do |t|
    t.string :name
    t.string :ancestry
  end
  add_index :items, :ancestry
end

describe AncestryJoins do
  class Item < ActiveRecord::Base
    self.table_name = 'items'
    has_ancestry
    include AncestryJoins
  end

  before(:all) do
    # data setup
    a1 = Item.create name: 'a1'
    a2 = Item.create name: 'a2', parent: a1
    a3 = Item.create name: 'a3', parent: a2

    b1 = Item.create name: 'b1'
    b2 = Item.create name: 'b2', parent: b1
    b22 = Item.create name: 'b22', parent: b1
  end

  context 'all records' do
    it 'returns with parents' do
      expect(Item.all.with_ancestors.map(&:name)).to match_array(%w(
        a1
        a2 a1
        a3 a2 a1
        b1
        b2  b1
        b22 b1
      ))
    end
  end

  describe '#with_ancestors' do
    def names_for(name, **options)
      Item.where(name: name).with_ancestors(**options).map(&:name)
    end

    it 'returns itself' do
      expect(names_for('a1')).to(match_array(%w(a1)))
    end

    it 'returns itself and parents' do
      expect(names_for('a2')).to(match_array(%w(a1 a2)))
      expect(names_for('a3')).to(match_array(%w(a1 a2 a3)))
    end

    it 'returns first parent' do
      expect(names_for('a3', nth: 1)).to(match_array(%w(a1)))
    end
    it 'returns last child' do
      expect(names_for('a3', nth_reverse: 1)).to(match_array(%w(a3)))
    end
  end

  describe '#with_ancestors_only' do
    def names_for(name)
      Item.where(name: name).with_ancestors_only.map(&:name)
    end

    it 'returns nothing' do
      expect(names_for('a1')).to be_empty
    end

    it 'returns only its parent' do
      expect(names_for('a2')).to(match_array(%w(a1)))
      expect(names_for('a3')).to(match_array(%w(a1 a2)))
    end
  end

  describe '#with_ancestors_leafs_only' do
    it 'returns only children' do
      children = Item.with_ancestors_leafs_only.map(&:name)
      expect(children).to(
        match_array(%w(a3 b2 b22))
      )
    end
  end
end
