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

require 'safe_active_record/load'

# It's unreliable to reverse the patch when there is a chain of patches.
# This method is therefore only used for testing purpose where we know there
# isn't a patch chain.
def remove_load_patch
  restore = proc do |original_method|
    Kernel.module_eval do
      if private_method_defined? :"safe_ar_original_#{original_method}"
        alias_method original_method, :"safe_ar_original_#{original_method}"
        undef :"safe_ar_original_#{original_method}"
      end
    end
  end

  restore.call(:require)
  restore.call(:load)
  restore.call(:require_relative)
end

describe 'monkey patch Kernel.require load and requrie_relative,' do
  context "SafeRecordManager hasn't been activated" do
    before(:all) do
      @mgr = SafeActiveRecord::SafeQueryManager.new
      SafeActiveRecord.apply_load_patch(@mgr)
    end

    it 'aliases original require method' do
      expect(Kernel.private_method_defined?(:safe_ar_original_require)).to be true
    end

    it 'loads as usual' do
      expect(require('loaded_1')).to be true
      expect(load('loaded_1.rb')).to be true
    end

    it 'loads static symbol' do
      expect(Symbol.all_symbols.grep(/^load static query 1$/).empty?).to be false
    end

    it "doesn't add static symbol to safe set yet" do
      expect(@mgr.safe_query?('load static query 1'.to_sym)).to be false
    end

    after(:all) do
      remove_load_patch
    end
  end

  context 'SafeRecordManager has been activated with intercept_load' do
    it "allows static symbol loaded prior to SafeRecordManager's activation" do
      expect(require('loaded_4')).to be true

      mgr = SafeActiveRecord::SafeQueryManager.new
      SafeActiveRecord.apply_load_patch(mgr)
      mgr.activate!({ intercept_load: true })

      expect(mgr.safe_query?('load static query 4'.to_sym)).to be true
    end

    it "allows static symbol loaded after SafeRecordManager's activation" do
      mgr = SafeActiveRecord::SafeQueryManager.new
      SafeActiveRecord.apply_load_patch(mgr)
      mgr.activate!({ intercept_load: true })

      expect(load('loaded_3.rb')).to be true
      expect(mgr.safe_query?('load static query 3'.to_sym)).to be true

      expect(require('loaded_5')).to be true
      expect(mgr.safe_query?('load static query 5'.to_sym)).to be true

      expect(require_relative('relative_loaded_1')).to be true
      expect(mgr.safe_query?('relative load static query 1'.to_sym)).to be true
    end

    after(:each) do
      remove_load_patch
    end
  end
end
