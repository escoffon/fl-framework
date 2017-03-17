require 'minitest/autorun'
require 'fl/framework'
require 'test_classes_helper'
  
class AccessTest < Minitest::Test
  def test_base_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = BaseAsset.new('a1_10', 10)
    a2_80 = BaseAsset.new('a2_80', 80)
    a3_110 = BaseAsset.new('a3_110', 110)
    a4_200 = BaseAsset.new('a4_200', 200)

    assert_nil BaseAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, BaseAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, BaseAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil BaseAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil BaseAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, BaseAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)
  end

  def test_inline_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = InlineAsset.new('a1_10', 10)
    a2_80 = InlineAsset.new('a2_80', 80)
    a3_110 = InlineAsset.new('a3_110', 110)
    a4_200 = InlineAsset.new('a4_200', 200)

    assert_nil InlineAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, InlineAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, InlineAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil InlineAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil InlineAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, InlineAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)
  end

  def test_override_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = OverrideAsset.new('a1_10', 10)
    a2_80 = OverrideAsset.new('a2_80', 80)
    a3_110 = OverrideAsset.new('a3_110', 110)
    a4_200 = OverrideAsset.new('a4_200', 200)

    assert_nil OverrideAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_nil OverrideAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, OverrideAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil OverrideAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil OverrideAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, OverrideAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)
  end

  def test_extend_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = ExtendAsset.new('a1_10', 10)
    a2_80 = ExtendAsset.new('a2_80', 80)
    a3_110 = ExtendAsset.new('a3_110', 110)
    a4_200 = ExtendAsset.new('a4_200', 200)

    assert_nil ExtendAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, ExtendAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, ExtendAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil ExtendAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil ExtendAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, ExtendAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil ExtendAsset.permission?(u1_50, ExtendAccess::CLASS_OP)
    assert_equal :ok, ExtendAsset.permission?(u2_120, ExtendAccess::CLASS_OP)
    assert_equal :ok, ExtendAsset.permission?(u3_145, ExtendAccess::CLASS_OP)

    assert_nil a1_10.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a1_10.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a1_10.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a2_80.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a2_80.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a2_80.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a3_110.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a3_110.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a3_110.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a4_200.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a4_200.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_nil a4_200.permission?(u3_145, ExtendAccess::INSTANCE_OP)
  end
end
