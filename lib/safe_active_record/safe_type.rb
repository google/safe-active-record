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
  class TrustedSymbol
    attr_reader :raw_str

    def initialize(str)
      raise ArgumentError, 'SafeStaticString only takes in Symbol type' unless str.instance_of?(Symbol)

      mgr = SafeActiveRecord.safe_query_manager

      raise StandardErrors, "SafeQueryManager must be activated before instantiation of #{self.class.name}!" unless mgr.activated?

      unless mgr.safe_query?(str)
        raise ArgumentError, "The symbol isn't found trusted. It could be that it is created dynamically from a string," \
                             "or the source where the caller belongs to isn't eager loaded."
      end

      @raw_str = str.to_s
    end

    freeze
  end

  # UncheckedString will be taken as-is by Active Record APIs.
  # It should only be used for queries that can not be constructed from constant
  # strings, but is trustworthy and therefore warrants a rigorous code review.
  class UncheckedString < String
    # Disallow inheritance so that developers won't abuse unchecked string
    # unnoticeably in code review, or by scanners that look only for
    # UncheckedString.
    def self.inherited(_subclass)
      raise StandardError, 'Inheriting from SafeActiveRecord::UncheckedString is not supported'
    end

    freeze
  end

  # RiskilyAssumeTrustedString will be taken as-is by Active Record APIs.
  # Use of this type could potentially result in security vulnerabilities.
  # It should only be used to gradually migrate to TrustedSymbol and
  # UncheckedString, and enventually dropped entirely as it carries security
  # risks.
  class RiskilyAssumeTrustedString < String
    # Disallow inheritance so that developers won't abuse unchecked string
    # unnoticeably in code review, or by scanners that look only for
    # RiskilyAssumeTrustedString.
    def self.inherited(_subclass)
      raise StandardError, 'Inheriting from SafeActiveRecord::RiskilyAssumeTrustedString is not supported'
    end
  end
end
