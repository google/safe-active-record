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
require 'safe_active_record/active_record_monkeypatch'
require 'safe_active_record/load'
require 'safe_active_record/reporter'

module SafeActiveRecord
  def self.activate!(options = {})
    # make sure it has been instantiated
    mgr = safe_query_manager
    mgr.activate! options
    # Dynamically apply the decoraters only when needed to boost performance
    apply_load_patch mgr if mgr.intercept_load?
    lock_module
  end

  # Set the callback Proc to report violation of safe type usage.
  # `handler` takes one arguement, the exception.
  def self.report_handler(handler)
    @@report_handler = handler
  end
end
