require 'test_helper'

require 'fl/framework/core/parameters_helper'

module Fl::Framework::Test
  module Find
    module ClassMethods
    end

    module InstanceMethods
    end

    def self.included(base)
      base.extend ClassMethods
      base.instance_eval do
      end
      base.class_eval do
        include InstanceMethods

        def self.find(id)
          if (id.to_i % 2) == 0
            self.new(id)
          else
            raise "not found"
          end
        end
      end
    end
  end

  class TestClassOne
    def self.find(id)
      if (id.to_i % 2) == 0
        TestClassOne.new(id)
      else
        raise "not found"
      end
    end

    attr_reader :id

    def initialize(id)
      @id = id.to_i
    end
  end

  class TestClassWithModuleOne
    include Find

    attr_reader :id

    def initialize(id)
      @id = id.to_i
    end
  end

  class TestClassWithModuleTwo
    include Find

    attr_reader :id

    def initialize(id)
      @id = id.to_i
    end
  end

  class TestClassFour
    include Fl::Framework::Core::ParametersHelper

    attr_reader :obj

    def initialize(params)
      @obj = object_from_parameter(params, :obj, [ Fl::Framework::Test::TestClassOne ])
    end
  end

  class TestClassSix
    include Fl::Framework::Core::ParametersHelper

    attr_reader :obj

    def initialize(params)
      @obj = object_from_parameter(params, :obj, Proc.new { |obj| obj.class.include?(Find) })
    end
  end

  class ParametersHelperTest < TestCase
    test 'object_from_parameters' do
      ph = Fl::Framework::Core::ParametersHelper

      o10 = Fl::Framework::Test::TestClassOne.new(10)
      f = ph.object_from_parameter(o10)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o10.id, f.id

      o11 = Fl::Framework::Test::TestClassOne.new(11)
      f = ph.object_from_parameter(o11)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o11.id, f.id

      f = ph.object_from_parameter('Fl::Framework::Test::TestClassOne/10')
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id
      
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter('Fl::Framework::Test::TestClassOne/11')
      }
      
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter('Fl::Framework::Test::TestClassTwo/10')
      }

      f = ph.object_from_parameter({ obj: o10 }, :obj)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o10.id, f.id

      f = ph.object_from_parameter({ v: o11, obj: o10 }, :v)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o11.id, f.id

      f = ph.object_from_parameter({ obj: 'Fl::Framework::Test::TestClassOne/10' }, :obj)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: 'Fl::Framework::Test::TestClassOne/11' }, :obj)
      }

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: 'Fl::Framework::Test::TestClassOne/10' }, :v)
      }
      
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ o: 'Fl::Framework::Test::TestClassTwo/10' }, :o)
      }

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: 10 })
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: '10' })
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: 10 }, :obj)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: '10' }, :obj)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: 11 }, :obj)
      }

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: '11' }, :obj)
      }
      
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassTwo', id: '10' }, :o)
      }

      f = ph.object_from_parameter({ obj: { type: 'Fl::Framework::Test::TestClassOne', id: 10 } }, :obj)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      f = ph.object_from_parameter({ o: { type: 'Fl::Framework::Test::TestClassOne', id: '10' } }, :o)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: { type: 'Fl::Framework::Test::TestClassOne', id: 11 } }, :obj)
      }

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: { type: 'Fl::Framework::Test::TestClassOne', id: 10 } }, :o)
      }
    end

    test 'object_from_parameters_expect' do
      ph = Fl::Framework::Core::ParametersHelper

      o10 = Fl::Framework::Test::TestClassOne.new(10)
      f = ph.object_from_parameter(o10, nil, Fl::Framework::Test::TestClassOne)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o10.id, f.id

      o11 = Fl::Framework::Test::TestClassOne.new(11)
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter(o11, :obj, Fl::Framework::Test::TestClassWithModuleOne)
      }

      f = ph.object_from_parameter('Fl::Framework::Test::TestClassOne/10', :v, Fl::Framework::Test::TestClassOne)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id
      
      f = ph.object_from_parameter('Fl::Framework::Test::TestClassOne/10', :v, 'Fl::Framework::Test::TestClassOne')
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id
      
      f = ph.object_from_parameter({ obj: o10 }, :obj, Fl::Framework::Test::TestClassOne)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o10.id, f.id

      f = ph.object_from_parameter({ v: o11, obj: o10 }, :v, [ Fl::Framework::Test::TestClassOne, Fl::Framework::Test::TestClassWithModuleOne ])
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal o11.id, f.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: 'Fl::Framework::Test::TestClassOne/10' }, :obj, [ 'Fl::Framework::Test::TestClassWithModuleOne' ])
      }

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ obj: 'Fl::Framework::Test::TestClassOne/10' }, :obj, [ Fl::Framework::Test::TestClassWithModuleOne ])
      }

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: 10 }, nil, Fl::Framework::Test::TestClassOne)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: '10' }, nil, [ 'Fl::Framework::Test::TestClassOne' ])
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      p = Proc.new { |o| o.is_a?(Fl::Framework::Test::TestClassOne) }
      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: 10 }, :obj, p)
      assert_instance_of Fl::Framework::Test::TestClassOne, f
      assert_equal 10, f.id

      p = Proc.new { |o| o.is_a?(Fl::Framework::Test::TestClassWithModuleOne) }
      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassOne', id: '10' }, :obj, p)
      }

      p = Proc.new { |o| o.class.include?(Find) }
      f = ph.object_from_parameter({ type: 'Fl::Framework::Test::TestClassWithModuleOne', id: 20 }, nil, p)
      assert_instance_of Fl::Framework::Test::TestClassWithModuleOne, f
      assert_equal 20, f.id
    end

    test 'object_from_parameters_embedded' do
      o10 = Fl::Framework::Test::TestClassOne.new(10)
      o12 = Fl::Framework::Test::TestClassWithModuleOne.new(12)
      o14 = Fl::Framework::Test::TestClassWithModuleTwo.new(14)

      o = Fl::Framework::Test::TestClassFour.new(obj: o10)
      assert_instance_of Fl::Framework::Test::TestClassOne, o.obj
      assert_equal o10.id, o.obj.id

      o = Fl::Framework::Test::TestClassFour.new(obj: 'Fl::Framework::Test::TestClassOne/10')
      assert_instance_of Fl::Framework::Test::TestClassOne, o.obj
      assert_equal 10, o.obj.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassFour.new(obj: 'Fl::Framework::Test::TestClassOne/11')
      }    

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassFour.new(obj: 'Fl::Framework::Test::TestClassWithModuleOne/20')
      }    

      o = Fl::Framework::Test::TestClassFour.new(obj: { type: 'Fl::Framework::Test::TestClassOne', id: '10' })
      assert_instance_of Fl::Framework::Test::TestClassOne, o.obj
      assert_equal 10, o.obj.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassFour.new(obj: { type: 'Fl::Framework::Test::TestClassOne', id: 11 })
      }    

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassFour.new(obj: { type: 'Fl::Framework::Test::TestClassWithModuleOne', id: 20 })
      }

      o = Fl::Framework::Test::TestClassSix.new(obj: o12)
      assert_instance_of Fl::Framework::Test::TestClassWithModuleOne, o.obj
      assert_equal o12.id, o.obj.id

      o = Fl::Framework::Test::TestClassSix.new(obj: o14)
      assert_instance_of Fl::Framework::Test::TestClassWithModuleTwo, o.obj
      assert_equal o14.id, o.obj.id

      o = Fl::Framework::Test::TestClassSix.new(obj: 'Fl::Framework::Test::TestClassWithModuleOne/20')
      assert_instance_of Fl::Framework::Test::TestClassWithModuleOne, o.obj
      assert_equal 20, o.obj.id

      o = Fl::Framework::Test::TestClassSix.new(obj: 'Fl::Framework::Test::TestClassWithModuleTwo/20')
      assert_instance_of Fl::Framework::Test::TestClassWithModuleTwo, o.obj
      assert_equal 20, o.obj.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassSix.new(obj: 'Fl::Framework::Test::TestClassWithModuleOne/11')
      }    

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassSix.new(obj: 'Fl::Framework::Test::TestClassOne/20')
      }    

      o = Fl::Framework::Test::TestClassSix.new(obj: { type: 'Fl::Framework::Test::TestClassWithModuleOne', id: '40' })
      assert_instance_of Fl::Framework::Test::TestClassWithModuleOne, o.obj
      assert_equal 40, o.obj.id

      o = Fl::Framework::Test::TestClassSix.new(obj: { type: 'Fl::Framework::Test::TestClassWithModuleTwo', id: 40 })
      assert_instance_of Fl::Framework::Test::TestClassWithModuleTwo, o.obj
      assert_equal 40, o.obj.id

      assert_raises(Fl::Framework::Core::ParametersHelper::ConversionError) {
        o = Fl::Framework::Test::TestClassSix.new(obj: { type: 'Fl::Framework::Test::TestClassWithModuleOne', id: 11 })
      }    
    end
  end
end
