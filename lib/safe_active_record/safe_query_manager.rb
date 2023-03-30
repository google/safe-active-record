# frozen_string_literal: true

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

require 'set'
require 'singleton'

module SafeActiveRecord
  @@safe_query_manager = nil
  class SafeQueryManager
    OPTIONS = %i[safe_query_mode dry_run intercept_load].freeze

    DEFAULT_OPTIONS = {
      safe_query_mode: :strict,
      dry_run: false,
      intercept_load: false
    }.freeze

    def initialize
      @safe_queries = Set.new
    end

    def activate!(options = {})
      self.class.freeze

      @options = DEFAULT_OPTIONS.merge options

      unknown = @options.reject { |o| OPTIONS.include? o }

      unless unknown.empty?
        raise ArgumentError,
              "Unknown options #{unknown}"

      end

      unless %i[strict lax].include? @options[:safe_query_mode]
        raise ArgumentError,
              "Unknown safe_query_mode #{@options[:safe_query_mode]}"

      end

      unless [true, false].include? @options[:dry_run]
        raise ArgumentError,
              'dry_run parameter only takes true/false value'

      end

      unless [true, false].include? @options[:intercept_load]
        raise ArgumentError,
              'intercept_load parameter only takes true/false value'

      end

      add_safe_queries Symbol.all_symbols

      @safe_queries.freeze unless @options[:intercept_load]

      @activated = true

      # This has to be the last statement.
      freeze
    end

    # lax mode allow the usage of transitive type RiskilyAssumeTrustedString
    # during migration to SafeActiveRecord.
    def lax_mode?
      @options[:safe_query_mode] == :lax
    end

    def activated?
      @activated
    end

    def dry_run?
      @options[:dry_run]
    end

    def intercept_load?
      @options[:intercept_load]
    end

    def add_safe_queries(queries)
      @safe_queries.merge queries
    end

    def safe_query?(query)
      @safe_queries.include? query
    end
  end

  def self.safe_query_manager=(mgr)
    @@safe_query_manager = mgr
  end

  def self.safe_query_manager
    return @@safe_query_manager if @@safe_query_manager

    @@safe_query_manager = SafeQueryManager.new
  end

  def self.lock_module
    class << self
      undef_method :safe_query_manager=
    end
    freeze
  end
end
