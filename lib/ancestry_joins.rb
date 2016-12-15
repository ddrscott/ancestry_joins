require 'ancestry_joins/version'
require 'active_record'
require 'pg'
require 'ancestry'
require 'active_support/concern'

module AncestryJoins
  extend ActiveSupport::Concern

  included do
    case connection.adapter_name.downcase.to_sym
    when :postgresql
      # Helper to add all selection fields. This is the default behavior until
      # you add your own selections.
      scope :with_star, -> { select("#{table_name}.*") }

      # Helper to get the root_id from the ancestry string column.
      scope :with_root_id, -> {
        select("coalesce(nullif(trim(split_part(#{table_name}.#{ancestry_column}, '/', 1)), ''), #{table_name}.#{primary_key}::text) AS ancestry_root_id")
      }

      # Joins ancestors to the existing scope.
      # It's important to make this the last scope for efficiency.
      # @params [Boolean] include_self will keep the current record in the
      # results. Otherwise, you'll only get the ancestors. `include_self`
      # defaults to `true`
      # @params [Integer] nth limit the results to just the nth child in the
      # ancestry.
      # @params [Integer] nth_reverse opposite of `nth`. Useful for getting the
      # tips of the ancestry.
      scope :with_ancestors, ->(include_self: true, nth: nil, nth_reverse: nil) {
        primary_key_type = columns.detect { |d| d.name == primary_key }.sql_type

        select_nth_ancestor_id = <<-SQL.squish
                SELECT *, row_number() OVER ()
                FROM unnest(string_to_array(nullif(#{table_name}.#{ancestry_column}, ''), '/')::#{primary_key_type}[] #{include_self ? " || ARRAY[#{table_name}.#{primary_key}]" : nil})
        SQL

        query = select('ancestors.*')
                .select('rank() OVER (PARTITION BY ancestors.ancestry_root_id ORDER BY ancestor_ids.nth desc nulls last) AS ancestry_nth_reverse')
                .select('ancestor_ids.nth AS ancestry_nth')
                .joins("JOIN LATERAL (#{select_nth_ancestor_id}) AS ancestor_ids(id, nth) ON true")
                .joins("JOIN (#{unscoped.with_star.with_root_id.to_sql}) AS ancestors ON ancestors.#{primary_key} = ancestor_ids.#{primary_key}")

        query = unscoped.from("(#{query.to_sql}) AS #{table_name}")

        query = query.where('ancestry_nth = ?', nth) if nth
        query = query.where('ancestry_nth_reverse = ?', nth_reverse) if nth_reverse
        query
      }

      # Helper to exclude current record from results.
      scope :with_ancestors_only, ->(**options) { with_ancestors(include_self: false, **options) }

      # Helper to build `nth_reverse: 1`
      scope :with_ancestors_leafs_only, ->(**options) { with_ancestors(nth_reverse: 1, **options) }
    else
      raise NotImplementedError, "Unknown adapter type `#{adapter_type}`"
    end
  end
end
