require 'spec_helper'

describe "Scope" do
  with_mongo_model

  before do
    class Unit
      inherit Mongo::Model
      collection :units

      attr_accessor :name, :status, :race
    end
  end

  after{remove_constants :Unit, :Protoss}

  describe 'current scope' do
    it "should affect finders" do
      Unit.build(name: 'Zeratul',  status: 'alive').save!
      Unit.build(name: 'Jim',      status: 'alive').save!
      Unit.build(name: 'Tassadar', status: 'dead').save!

      Unit.count.should == 3
      Unit.all.size.should == 3
      Unit.first(name: 'Tassadar').should_not be_nil
      Unit.first!(name: 'Tassadar').should_not be_nil

      Unit.stub!(:current_scope).and_return(Unit.query(status: 'alive'))

      Unit.count.should == 2
      Unit.all.size.should == 2
      Unit.first(name: 'Tassadar').should be_nil
      -> {Unit.first!(name: 'Tassadar')}.should raise_error(Mongo::NotFound)

      # should be merged with finders
      Unit.count(status: 'dead').should == 1
      Unit.all(status: 'dead').size.should == 1
      Unit.first(name: 'Tassadar', status: 'dead').should_not be_nil
      Unit.first!(name: 'Tassadar', status: 'dead').should_not be_nil
    end
  end

  describe 'default scope' do
    it "should not affect objects without default_scope" do
      Unit.current_scope.should be_nil
    end

    it "should allow to define default scope" do
      Unit.default_scope status: 'alive'

      Unit.current_scope.should == Unit.query(status: 'alive')

      Unit.default_scope do
        {status: 'alive'}
      end
      Unit.current_scope.should == Unit.query(status: 'alive')
    end

    it "should inherit default scope" do
      Unit.default_scope status: 'alive'

      class Protoss < Unit; end
      Protoss.current_scope.should == Unit.query(status: 'alive')

      Protoss.default_scope status: 'dead'
      Unit.current_scope.should == Unit.query(status: 'alive')
      Protoss.current_scope.should == Protoss.query(status: 'dead')
    end
  end

  describe 'scope' do
    it "should allow to define scope" do
      Unit.scope :alive, status: 'alive'
      Unit.alive.current_scope.should == Unit.query(status: 'alive')

      Unit.scope :alive do
        {status: 'alive'}
      end
      Unit.alive.current_scope.should == Unit.query(status: 'alive')
    end

    it 'scope should affect current scope' do
      Unit.scope :alive, status: 'alive'

      Unit.current_scope.should be_nil

      Unit.alive.current_scope.should == Unit.query(status: 'alive')
      Unit.alive.class.should == Mongo::Model::Query
    end

    it 'should be merged with default scope' do
      Unit.default_scope race: 'Protoss'
      Unit.scope :alive, status: 'alive'
      Unit.alive.current_scope.should == Unit.query(race: 'Protoss', status: 'alive')
    end

    it 'should allow to chain scopes' do
      Unit.scope :alive, status: 'alive'
      Unit.scope :protosses, race: 'Protoss'
      Unit.alive.protosses.current_scope.should == Unit.query(race: 'Protoss', status: 'alive')
    end
  end

  describe 'querying with scope' do
    it "shouldn't allow to nest exclusive scope" do
      -> {
        Unit.with_exclusive_scope do
          Unit.with_exclusive_scope{}
        end
      }.should raise_error(/exclusive scope already applied/)

      -> {
        Unit.with_exclusive_scope do
          Unit.with_scope{}
        end
      }.should raise_error(/exclusive scope already applied/)
    end

    it "should clear other scopes when exclusive scope used" do
      Unit.default_scope status: 'alive'

      Unit.with_scope race: 'Protoss' do
        Unit.current_scope.should == Unit.query(status: 'alive', race: 'Protoss')

        Unit.with_exclusive_scope do
          Unit.current_scope.should == Unit.query({})
        end

        Unit.with_exclusive_scope race: 'Terran' do
          Unit.current_scope.should == Unit.query(race: 'Terran')
        end
      end
    end

    it "should access current scope" do
      Unit.with_scope status: 'alive' do
        Unit.current_scope.should == Unit.query(status: 'alive')
      end
    end

    it "should merge scopes" do
      Unit.default_scope status: 'alive'
      Unit.with_scope race: 'Protoss' do
        Unit.with_scope name: 'Zeratul' do
          Unit.current_scope.should == Unit.query(name: 'Zeratul', race: 'Protoss', status: 'alive')
        end
      end
    end
  end

  describe 'handy scopes' do
    it "should provide limit, skip and sort scopes" do
      query = Unit.skip(30).limit(10).sort([:name, 1]).snapshot
      query.selector.should == {}
      query.options.should == {skip: 30, limit: 10, sort: [[:name, 1]], snapshot: true}
    end

    it "should understand simplified form of sort scope" do
      query = Unit.sort(:name)
      query.options.should == {sort: [[:name, 1]]}

      query = Unit.sort(:race, :name)
      query.options.should == {sort: [[:race, 1], [:name, 1]]}
    end

    it 'should provide paginate' do
      query = Unit.paginate(4, 10)
      query.selector.should == {}
      query.options.should == {skip: 30, limit: 10}
    end
  end
end