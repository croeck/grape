require 'spec_helper'

describe Grape::Entity do
  let(:fresh_class){ Class.new(Grape::Entity) }

  context 'class methods' do
    subject{ fresh_class }

    describe '.expose' do
      context 'multiple attributes' do
        it 'should be able to add multiple exposed attributes with a single call' do
          subject.expose :name, :email, :location
          subject.exposures.size.should == 3
        end

        it 'should set the same options for all exposures passed' do
          subject.expose :name, :email, :location, :foo => :bar
          subject.exposures.values.each{|v| v.should == {:foo => :bar}}
        end
      end

      context 'option validation' do
        it 'should make sure that :as only works on single attribute calls' do
          expect{ subject.expose :name, :email, :as => :foo }.to raise_error(ArgumentError)
          expect{ subject.expose :name, :as => :foo }.not_to raise_error
        end
      end

      context 'with a block' do
        it 'should error out if called with multiple attributes' do
          expect{ subject.expose(:name, :email) do
            true
          end }.to raise_error(ArgumentError)
        end

        it 'should set the :proc option in the exposure options' do
          block = lambda{|obj,opts| true }
          subject.expose :name, &block
          subject.exposures[:name][:proc].should == block
        end
      end
    end

    describe '.represent' do
      it 'should return a single entity if called with one object' do
        subject.represent(Object.new).should be_kind_of(subject)
      end

      it 'should return multiple entities if called with a collection' do
        representation = subject.represent(4.times.map{Object.new})
        representation.should be_kind_of(Array)
        representation.size.should == 4
        representation.reject{|r| r.kind_of?(subject)}.should be_empty
      end

      it 'should add the :collection => true option if called with a collection' do
        representation = subject.represent(4.times.map{Object.new})
        representation.each{|r| r.options[:collection].should be_true}
      end
    end

    describe '#initialize' do
      it 'should take an object and an optional options hash' do
        expect{ subject.new(Object.new) }.not_to raise_error
        expect{ subject.new }.to raise_error(ArgumentError)
        expect{ subject.new(Object.new, {}) }.not_to raise_error
      end

      it 'should have attribute readers for the object and options' do
        entity = subject.new('abc', {})
        entity.object.should == 'abc'
        entity.options.should == {}
      end
    end
  end

  context 'instance methods' do
    let(:model){ mock(attributes) }
    let(:attributes){ {
      :name => 'Bob Bobson', 
      :email => 'bob@example.com',
      :friends => [
        mock(:name => "Friend 1", :email => 'friend1@example.com', :friends => []), 
        mock(:name => "Friend 2", :email => 'friend2@example.com', :friends => [])
      ]
    } }
    subject{ fresh_class.new(model) }

    describe '#serializable_hash' do
      it 'should not throw an exception if a nil options object is passed' do
        expect{ fresh_class.new(model).serializable_hash(nil) }.not_to raise_error
      end

      it 'should not blow up when the model is nil' do
        fresh_class.expose :name
        expect{ fresh_class.new(nil).serializable_hash }.not_to raise_error
      end
    end

    describe '#value_for' do
      before do
        fresh_class.class_eval do
          expose :name, :email
          expose :friends, :using => self
          expose :computed do |object, options|
            options[:awesome]
          end
        end
      end

      it 'should pass through bare expose attributes' do
        subject.send(:value_for, :name).should == attributes[:name]
      end

      it 'should instantiate a representation if that is called for' do
        rep = subject.send(:value_for, :friends)
        rep.reject{|r| r.is_a?(fresh_class)}.should be_empty
        rep.first.serializable_hash[:name].should == 'Friend 1'
        rep.last.serializable_hash[:name].should == 'Friend 2'
      end

      it 'should call through to the proc if there is one' do
        subject.send(:value_for, :computed, :awesome => 123).should == 123
      end
    end

    describe '#key_for' do
      it 'should return the attribute if no :as is set' do
        fresh_class.expose :name
        subject.send(:key_for, :name).should == :name
      end

      it 'should return a symbolized version of the attribute' do
        fresh_class.expose :name
        subject.send(:key_for, 'name').should == :name
      end

      it 'should return the :as alias if one exists' do
        fresh_class.expose :name, :as => :nombre
        subject.send(:key_for, 'name').should == :nombre
      end
    end

    describe '#conditions_met?' do
      it 'should only pass through hash :if exposure if all attributes match' do
        exposure_options = {:if => {:condition1 => true, :condition2 => true}}

        subject.send(:conditions_met?, exposure_options, {}).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true).should be_true
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true, :other => true).should be_true
      end

      it 'should only pass through proc :if exposure if it returns truthy value' do
        exposure_options = {:if => lambda{|obj,opts| opts[:true]}}

        subject.send(:conditions_met?, exposure_options, :true => false).should be_false
        subject.send(:conditions_met?, exposure_options, :true => true).should be_true
      end

      it 'should only pass through hash :unless exposure if any attributes do not match' do
        exposure_options = {:unless => {:condition1 => true, :condition2 => true}}

        subject.send(:conditions_met?, exposure_options, {}).should be_true
        subject.send(:conditions_met?, exposure_options, :condition1 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true, :other => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => false).should be_true
      end

      it 'should only pass through proc :unless exposure if it returns falsy value' do
        exposure_options = {:unless => lambda{|object,options| options[:true] == true}}

        subject.send(:conditions_met?, exposure_options, :true => false).should be_true
        subject.send(:conditions_met?, exposure_options, :true => true).should be_false
      end
    end
  end
end
