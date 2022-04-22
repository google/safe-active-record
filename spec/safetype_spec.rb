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

require 'safe_active_record/safe_type'

describe SafeActiveRecord::TrustedSymbol do
  context "SafeQueryManager hasn't been activated" do
    before(:all) do
      SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
    end
    it 'raise exception due to SafeQueryManager not activated' do
      expect { SafeActiveRecord::TrustedSymbol.new('a string') }.to raise_error(StandardError)
      expect { SafeActiveRecord::TrustedSymbol.new(:'a static symbol') }.to raise_error(StandardError)
      expect { SafeActiveRecord::TrustedSymbol.new('a dynamic symbol'.to_sym) }.to raise_error(StandardError)
    end
  end

  context 'SafeQueryManager has been activated' do
    before(:all) do
      SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
      SafeActiveRecord.safe_query_manager.activate!
    end
    it "doesn't take String type input" do
      expect { SafeActiveRecord::TrustedSymbol.new('a string') }.to raise_error(ArgumentError)
    end

    it 'allows static symbols' do
      s = SafeActiveRecord::TrustedSymbol.new(:'a static symbol 2')
      expect(s.raw_str).to be == 'a static symbol 2'
    end

    it 'denies dynamic symbols' do
      expect { SafeActiveRecord::TrustedSymbol.new('a dynamic symbol 2'.to_sym) }.to raise_error(ArgumentError)
    end
  end
end

describe SafeActiveRecord::UncheckedString do
  it "doesn't allow inheritance" do
    expect do
      class AnotherUncheckedString < SafeActiveRecord::UncheckedString
      end
    end.to raise_error(StandardError)
  end
end
