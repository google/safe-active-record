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

require 'safe_active_record/safe_query_manager'
require 'set'

module SafeActiveRecord
  @visited = Set.new
  @gemlist = Set.new

  def self.init_visited
    if $LOADED_FEATURES.is_a? Enumerable
      @visited.merge($LOADED_FEATURES)
      # Also merge the relative imported paths
      $LOADED_FEATURES.each do |path|
        # Add the relative path to the visited set, removing the base path from LOAD_PATH and the file extension
        $LOAD_PATH.each { |start_path| @visited.add(path[start_path.size + 1..-4]) if path.start_with?(start_path) }
      end
    end

    # Usually gem path starts with the gem name, exceptions incl. google gems
    # TODO: find a better way to do this without hardcoding specific use-cases
    @gemlist.merge(Gem::Specification.map { |g| g.name.start_with?('google-') ? 'google' : g.name })
  end

  def self.skip_symbols_diff(args, method)
    if args.instance_of?(Array) && args.size == 1 && args[0].instance_of?(String)
      # Load is mainly used for development to reload code without restarting the app
      return true if @visited.include?(args[0]) && method == 'require'

      # We don't need to process gems as SAR ignore SQL statements made in them
      return true if args[0].start_with?(Gem.dir)

      start_path = args[0].split('/', 2)[0]
      return true if !start_path.nil? && !start_path.empty? && @gemlist.include?(start_path)
    end
    false
  end

  def self.visit(args, method)
    return if method == 'load'
    return unless args.instance_of?(Array) && args.size == 1 && args[0].instance_of?(String)

    @visited.add(args[0])
  end

  def self.apply_load_patch(safe_query_mgr)
    # intercept_load should not be used in production
    if defined?(::Rails.env) && defined?(::Rails.logger.warn) && ::Rails.env.production?
      ::Rails.logger.warn(
        'SafeActiveRecord intercept_load should not be used in production, as this could cause significant performance issues, ' \
        'consider enabling eager_load and rake_eager_load instead.'
      )
    end

    apply_patch = proc do |original_method|
      unless Kernel.private_method_defined? :"safe_ar_original_#{original_method}"
        Kernel.module_eval do
          alias_method :"safe_ar_original_#{original_method}", original_method

          undef_method original_method

          define_method original_method do |*args|
            if safe_query_mgr.activated? && safe_query_mgr.intercept_load? && !SafeActiveRecord.skip_symbols_diff(args, original_method.to_s)
              pre_symbols = Symbol.all_symbols

              result = method(:"safe_ar_original_#{original_method}").call(*args)

              if result
                post_symbols = Symbol.all_symbols
                # If the last symbol of the pre table is the same in the post table, this means only additions happened
                # (no symbol deletion), so we can get the delta by slicing the post-table using the pre-table size as lower
                # boundary
                delta = if post_symbols[pre_symbols.size - 1] == pre_symbols[-1]
                          post_symbols[pre_symbols.size...]
                        else
                          post_symbols - pre_symbols
                        end
                safe_query_mgr.add_safe_queries delta if delta.is_a? Enumerable
              end
              SafeActiveRecord.visit(args, original_method.to_s)
            else
              result = method(:"safe_ar_original_#{original_method}").call(*args)
            end
            result
          end
        end
      end
    end

    apply_patch.call(:require)
    apply_patch.call(:load)

    # Kernel.require_relative needs special treatment due to relative path rebase.
    unless Kernel.private_method_defined? :safe_ar_original_require_relative
      Kernel.module_eval do
        alias_method :safe_ar_original_require_relative, :require_relative

        undef_method :require_relative

        define_method :require_relative do |path|
          # Only work on latest 3 callers to boost performance
          location = caller_locations[0..3].find { |x| x.base_label != 'require_relative' }
          base = File.dirname(location.absolute_path || location.path)
          abspath = File.expand_path(path, base)

          # No need to calculate the delta of symbol since `require` is already
          # decorated.

          # Both .rb and .so files can be imported. C extentions use .so files for example.
          abspath = "#{abspath}.rb" unless File.exist?(abspath)
          abspath = "#{abspath[...-3]}.so" unless File.exist?(abspath)
          require(File.realpath(abspath))
        end
      end
    end

    # Older version of ActiveSupport defines `require` and `load` methdos on
    # Object, and use them to load constants.
    # https://github.com/rails/rails/blob/0ed6ebcf9095c65330d3950cfb6b75ba7ea78853/activesupport/lib/active_support/dependencies.rb#L308
    Object.class_eval do
      r = method(:require)
      if r&.owner != Kernel
        define_method(:require, Kernel.instance_method(:require))
        private :require

        define_method(:load, Kernel.instance_method(:load))
        private :load
      end
    end
  end
end
