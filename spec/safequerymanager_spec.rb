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

describe SafeActiveRecord::SafeQueryManager do
  let(:static_query) { :'safequerymanager static query' }

  context 'activate with default parameter' do
    before(:all) do
      @mgr = SafeActiveRecord::SafeQueryManager.new
      @mgr.activate!

      @dynamic_query = "safequerymanager dynamic query #{Random.rand(1e9)}".to_sym
    end

    it 'has been activiated' do
      expect(@mgr.activated?).to be true
    end

    it 'is in strict mode' do
      expect(@mgr.lax_mode?).to be false
    end

    it 'raises exception if registering addtional safe queries' do
      expect { @mgr.add_safe_queries([@dynamic_query]) }.to raise_error(FrozenError)
    end

    it 'rejects unknown dynamic symbol' do
      expect(@mgr.safe_query?(@dynamic_query)).to be false
    end

    it 'accepts known static symbol' do
      expect(@mgr.safe_query?(static_query)).to be true
    end

    it "isn't in dry-run mode" do
      expect(@mgr.dry_run?).to be false
    end
  end

  context 'activated with lax mode parameter' do
    before(:all) do
      @mgr = SafeActiveRecord::SafeQueryManager.new
      @mgr.activate!({ safe_query_mode: :lax })
    end

    it 'has been activated' do
      expect(@mgr.activated?).to be true
    end

    it 'is in lax mode' do
      expect(@mgr.lax_mode?).to be true
    end

    it 'accepts known static symbol' do
      expect(@mgr.safe_query?(static_query)).to be true
    end
  end

  context 'activated with dry-run parameter' do
    before(:all) do
      @mgr = SafeActiveRecord::SafeQueryManager.new
      @mgr.activate!({ dry_run: true })
    end

    it 'has been activated' do
      expect(@mgr.activated?).to be true
    end

    it 'is in dry-run mode' do
      expect(@mgr.dry_run?).to be true
    end
  end

  context 'activated with intercept_load parameter' do
    before(:all) do
      @mgr = SafeActiveRecord::SafeQueryManager.new
      @mgr.activate!({ intercept_load: true })

      @dynamic_query = "dynamic query #{Random.rand(1e9)}".to_sym
    end

    it 'rejects unknown dynamic symbol' do
      expect(@mgr.safe_query?(@dynamic_query)).to be false
    end

    it 'registers additional safe symbols' do
      expect { @mgr.add_safe_queries([@dynamic_query]) }.not_to raise_error
    end

    it 'accepts known dynamic symbol' do
      expect(@mgr.safe_query?(@dynamic_query)).to be true
    end
  end
end
