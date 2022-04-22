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

require 'active_record'
require 'safe_active_record/active_record_monkeypatch'
require 'safe_active_record/safe_type'

describe 'Active Record monkeypatch' do
  describe 'Query APIs' do
    before(:all) do
      conn = { adapter: 'sqlite3', database: 'foobar.db' }

      ActiveRecord::Base.establish_connection(conn)

      class Teacher < ActiveRecord::Base
        has_many :students
        connection.create_table table_name, force: true do |t|
          t.string :name
          t.integer :age
        end
      end

      class Student < ActiveRecord::Base
        belongs_to :teacher
        connection.create_table table_name, force: true do |t|
          t.string :name
          t.integer :teacher_id
        end
      end

      Teacher.create!(name: 'Alice', age: 1024).save!
      Teacher.create!(name: 'Bob', age: 42).save!
      Teacher.where(name: 'Bob').first.students.create!(name: 'Lily').save!
    end

    context "safequerymanager hasn't been activated" do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
        @bob = Teacher.where(name: 'Bob')
        @alice = Teacher.where(name: 'Alice')
      end

      describe 'where clause' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.where("name = 'Bob'")).to match_array(@bob)
        end
      end

      describe 'having clause' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.having('age > ?', 50).group(:name)).to match_array(@alice)
        end
      end

      describe 'annotation' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.annotate('first */ ; select *; /* ', 'second').where(name: 'Bob')).to match_array(@bob)
        end
      end

      describe 'group clause' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.where(name: 'Bob').group('name')).to match_array(@bob)
        end
      end

      describe 'joins' do
        it "doesn't raise error with String type argument" do
          expect do
            Teacher.joins('INNER JOIN students on students.teacher_id = teachers.id').where(name: 'Bob')
          end.not_to raise_error
        end
      end

      describe 'optimization hints' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.where(name: 'Bob').optimizer_hints('hints')).to match_array(@bob)
        end
      end

      describe 'order' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.where(name: 'Bob').order('age')).to match_array(@bob)
        end
      end

      describe 'reorder' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.where(name: 'Bob').reorder('age')).to match_array(@bob)
        end
      end

      describe 'select' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.select('*').where(name: 'Bob')).to match_array(@bob)
        end

        it 'works with block' do
          expect(Teacher.select { |r| r.name == 'Bob' }).to match_array(@bob)
        end
      end

      describe 'reselect' do
        it "doesn't raise error with String type argument" do
          expect(Teacher.reselect('*').where(name: 'Bob')).to match_array(@bob)
        end
      end

      describe 'from clause' do
        it "doesn't raise erorr with String type argument" do
          expect(Teacher.select('*').from('Teachers')).to match_array(Teacher.select('*'))
          expect(Teacher.select(:name).from(Teacher.select('*'), 'subquery')[0].name).to be == 'Alice'
        end
      end
    end

    context 'SafeQueryManager has been activated with lax mode set to false' do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
        SafeActiveRecord.safe_query_manager.activate!
        @bob = Teacher.where(name: 'Bob')
        @alice = Teacher.where(name: 'Alice')
      end

      describe 'where clause' do
        it 'allows hash type argument' do
          expect { Teacher.where(name: 'Bob') }.not_to raise_error
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.where(SafeActiveRecord::TrustedSymbol.new(:'name = ?'),
                               'Bob')).to match_array(Teacher.where(name: 'Bob'))
        end

        it "doesn't allow RiskilyAssumeTrustedString type argument" do
          expect do
            Teacher.where(SafeActiveRecord::RiskilyAssumeTrustedString.new("name = 'Bob'"))
          end.to raise_error(ArgumentError)
        end

        it "doesn't allow String type argument" do
          expect { Teacher.where("name = 'Bob'") }.to raise_error(ArgumentError)
        end
      end

      describe 'having clause' do
        it 'allows TrustedSymbol type argument' do
          expect(Teacher.having(SafeActiveRecord::TrustedSymbol.new(:'age > ?'),
                                50).group(:name)).to match_array(Teacher.where(name: 'Alice'))
        end

        it "doesn't allow String type argument" do
          expect { Teacher.having('age > ?', 50).group(:name) }.to raise_error(ArgumentError)
        end
      end

      describe 'annotation' do
        it "doesn't allow String type argument" do
          expect do
            Teacher.annotate('first */ ; select *; /* ', 'second').where(name: 'Bob')
          end.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.annotate(
            SafeActiveRecord::TrustedSymbol.new(:'first */ ; select *; /* '),
            SafeActiveRecord::TrustedSymbol.new(:second)
          ).where(name: 'Bob')).to match_array(@bob)
        end
      end

      describe 'group clause' do
        it "doesn't allow String type argument" do
          expect { Teacher.where(name: 'Bob').group('name') }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.where(name: 'Bob').group(SafeActiveRecord::TrustedSymbol.new(:name))).to match_array(@bob)
        end
      end

      describe 'joins' do
        it "doesn't allow String type argument" do
          expect do
            Teacher.joins('INNER JOIN students on students.teacher_id = teachers.id').where(name: 'Bob')
          end.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect do
            Teacher.joins(SafeActiveRecord::TrustedSymbol.new(
                            :'INNER JOIN students on students.teacher_id = teachers.id'
                          ))
          end.not_to raise_error
        end
      end

      describe 'optimization hints' do
        it "doesn't allow String type argument" do
          expect { Teacher.where(name: 'Bob').optimizer_hints('hints') }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.where(name: 'Bob').optimizer_hints(SafeActiveRecord::TrustedSymbol.new(:hints)))
            .to match_array(@bob)
        end
      end

      describe 'order' do
        it "doesn't allow String type argument" do
          expect { Teacher.where(name: 'Bob').order('age') }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.where(name: 'Bob').order(SafeActiveRecord::TrustedSymbol.new(:age))).to match_array(@bob)
        end
      end

      describe 'reorder' do
        it "doesn't allow String type argument" do
          expect { Teacher.where(name: 'Bob').reorder('age') }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.where(name: 'Bob').reorder(SafeActiveRecord::TrustedSymbol.new(:age))).to match_array(@bob)
        end
      end

      describe 'select' do
        it "doesn't allow String type argument" do
          expect { Teacher.select('*').where(name: 'Bob') }.to raise_error(ArgumentError)
        end

        it 'works with block' do
          expect(Teacher.select { |r| r.name == 'Bob' }).to match_array(@bob)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.select(SafeActiveRecord::TrustedSymbol.new(:'*')).where(name: 'Bob')).to match_array(@bob)
        end
      end

      describe 'reselect' do
        it "doesn't allow String type argument" do
          expect { Teacher.reselect('*').where(name: 'Bob') }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.reselect(SafeActiveRecord::TrustedSymbol.new(:'*')).where(name: 'Bob')).to match_array(@bob)
        end
      end

      describe 'from clause' do
        it "doesn't allow String type argument" do
          expect { Teacher.select(:name).from('Teachers') }.to raise_error(ArgumentError)
          expect { Teacher.select(:name).from(Teacher.select(:name), 'subquery')[0].name }.to raise_error(ArgumentError)
        end

        it 'allows TrustedSymbol type argument' do
          expect(Teacher.select(:name).from(SafeActiveRecord::TrustedSymbol
              .new(:Teachers))[0].name).to be == 'Alice'
          expect(Teacher.select(:name).from(Teacher.select(:name),
                                            SafeActiveRecord::TrustedSymbol.new(:subquery))[0].name)
            .to be == 'Alice'
        end
      end
    end

    context 'SafeQueryManager has been activated with lax mode set to false' do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
        SafeActiveRecord.safe_query_manager.activate!(safe_query_mode: :lax)
        @bob = Teacher.where(name: 'Bob')
        @alice = Teacher.where(name: 'Alice')
      end

      it 'allows RiskilyAssumeTrustedString type argument' do
        expect(Teacher.where(SafeActiveRecord::RiskilyAssumeTrustedString.new("name = 'Bob'"))).to match_array(@bob)
      end
    end
  end

  describe 'Arel.sql' do
    context "safequerymanager hasn't been activated" do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
      end

      it 'accepts string type input' do
        expect(Arel.sql('select * from anything')).to be == Arel::Nodes::SqlLiteral.new('select * from anything')
      end

      it 'accepts UncheckedString type input' do
        expect(Arel.sql(SafeActiveRecord::UncheckedString.new('select * from anything'))).to be ==
                                                                                             Arel::Nodes::SqlLiteral.new('select * from anything')
      end
    end

    context 'SafeQueryManager has been activated lax mode set to false' do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
        SafeActiveRecord.safe_query_manager.activate!
      end

      it 'does not accept string type input' do
        expect { Arel.sql('select * from anything') }.to raise_error(ArgumentError)
      end

      it 'accepts TrustedSymbol type input' do
        expect(Arel.sql(SafeActiveRecord::TrustedSymbol.new(:'select * from anything'))).to be ==
                                                                                            Arel::Nodes::SqlLiteral.new('select * from anything')
      end

      it 'accepts UncheckedString type input' do
        expect(Arel.sql(SafeActiveRecord::UncheckedString.new('select * from anything'))).to be ==
                                                                                             Arel::Nodes::SqlLiteral.new('select * from anything')
      end

      it "doesn't accept RiskilyAssumeTrustedString type input" do
        expect do
          Arel.sql(SafeActiveRecord::RiskilyAssumeTrustedString.new('select * from anything'))
        end.to raise_error(ArgumentError)
      end
    end

    context 'SafeQueryManager has been activated lax mode set to false' do
      before(:all) do
        SafeActiveRecord.safe_query_manager = SafeActiveRecord::SafeQueryManager.new
        SafeActiveRecord.safe_query_manager.activate!(safe_query_mode: :lax)
      end

      it 'accepts RiskilyAssumeTrustedString type input' do
        expect(Arel.sql(SafeActiveRecord::RiskilyAssumeTrustedString.new('select * from anything'))).to be ==
                                                                                                        Arel::Nodes::SqlLiteral.new('select * from anything')
      end
    end
  end
end
