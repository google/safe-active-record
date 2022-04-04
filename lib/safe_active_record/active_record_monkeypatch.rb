# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "safe_active_record/reporter"
require "safe_active_record/safe_type"
require "safe_active_record/safe_query_manager"

module SafeActiveRecord
    def self.check_arg(arg, idx, which_caller=1)
      case arg
      when SafeActiveRecord::UncheckedString # UncheckedString type needs to preceed String due to membership operation
      when SafeActiveRecord::RiskilyAssumeTrustedString
        # The class methods on the Relation object `delegate` to the scope object and skews the call stack by 1.
        which_caller += 1 if caller[which_caller].include?("/querying.rb")

        legacy_err = true
        err = "Warning: use of RiskilyAssumeTrustedSQLString in argument indexed #{idx} (0-based) when calling `#{caller_locations.first.base_label}` at #{caller[which_caller]}. The type should only be used during migration to SafeActiveRecord."
      when String
        # The class method on the Relation object `delegate`s to the scope object and skews the call stack by 1.
        which_caller += 1 if caller[which_caller].include?("/querying.rb")

        err = "Warning: untrusted String type detected by SafeActiveRecord in argument indexed #{idx} (0-based) when calling `#{caller_locations.first.base_label}` at #{caller[which_caller]}. Please rewrite the argument with type TrustedSymbol."
      when SafeActiveRecord::TrustedSymbol
        arg = arg.raw_str
      end

      mgr = SafeActiveRecord.safe_query_manager
      return arg unless mgr.activated?

      if err
        # Always report a violation.
        exception = ArgumentError.new(err)
        SafeActiveRecord.report_violation(exception)

        raise exception unless (mgr.dry_run? or (legacy_err and mgr.lax_mode?))
      end

      arg
    end
end

module ActiveRecord
  class Relation
    alias_method :safe_ar_original_annotate, :annotate
    def annotate(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_annotate(*args)
    end

    alias_method :safe_ar_original_group, :group
    def group(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_group(*args)
    end

    alias_method :safe_ar_original_joins, :joins
    def joins(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_joins(*args)
    end

    alias_method :safe_ar_original_optimizer_hints, :optimizer_hints
    def optimizer_hints(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_optimizer_hints(*args)
    end

    alias_method :safe_ar_original_order, :order
    def order(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_order(*args)
    end

    alias_method :safe_ar_original_reorder, :reorder
    def reorder(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_reorder(*args)
    end

    alias_method :safe_ar_original_reselect, :reselect
    def reselect(*args)
      args = args.map.with_index {|arg, idx| SafeActiveRecord.check_arg(arg, idx, 4)}
      safe_ar_original_reselect(*args)
    end

    alias_method :safe_ar_original_select, :select
    def select(*fields, &blk)
      fields = fields.map.with_index {|field, idx| SafeActiveRecord.check_arg(field, idx, 4)}
      safe_ar_original_select(*fields, &blk)
    end

    # where decorator also covers find_by which pretty much delegates to where.
    alias_method :safe_ar_original_where, :where
    def where(*args)
      args[0] = SafeActiveRecord.check_arg(args[0], 0) if !args.empty?
      safe_ar_original_where(*args)
    end

    alias_method :safe_ar_original_having, :having
    def having(opts, *rest)
      opts = SafeActiveRecord.check_arg(opts, 0) if !opts.blank?
      safe_ar_original_having(opts, *rest)
    end

    alias_method :safe_ar_original_from, :from
    def from(value, subquery_name = nil)
      value = SafeActiveRecord.check_arg(value, 0)
      subquery_name = SafeActiveRecord.check_arg(subquery_name, 1) if subquery_name
      safe_ar_original_from(value, subquery_name)
    end
  end
end

module Arel
  # Decorate Arel.sql creates sql from a raw string.
  # Arel::Nodes::SqlLiteral are not decorated as it's an internal type to Arel
  # and normally should not be instantiated directly. That said, users should
  # take an one-off effort to rewrite SqlLiteral creation through Arel.sql if
  # any.
  class << self
    alias_method :safe_ar_original_sql, :sql

    @active_record_dir = nil

    # sql takes in arguments of TrustedSymbol or UncheckedString type.
    # It accepts String type only for invocations internal to Active Record.
    def sql(raw_sql)
      # It assumes here the decorated method safe_ar_original_sql is the orginal and hasn't been decorated by others
      @active_record_dir ||=  File.dirname(File.realpath(method(:safe_ar_original_sql).source_location.first)) +"/"

      # Invocations internal to Active Record
      return safe_ar_original_sql(raw_sql) if caller_locations(1..1).first.absolute_path.start_with?(@active_record_dir)

      raw_sql = SafeActiveRecord.check_arg(raw_sql, 0)

      safe_ar_original_sql(raw_sql)
    end
  end
end
