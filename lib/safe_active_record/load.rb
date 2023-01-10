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

module SafeActiveRecord
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
            if safe_query_mgr.activated? && safe_query_mgr.intercept_load?
              pre_symbols = Symbol.all_symbols

              result = method(:"safe_ar_original_#{original_method}").call(*args)

              delta = Symbol.all_symbols - pre_symbols
              safe_query_mgr.add_safe_queries delta
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

    # Kernel.reqiure_relative needs special treatment due to relative path rebase.
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

          abspath = "#{abspath}.rb" unless File.exist?(abspath)
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
