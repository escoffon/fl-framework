require 'test_helper'

require 'fl/framework'
require 'test_classes_helper'
  
module Fl::Framework::Test
  class ModelHashTest < TestCase
    def to_hash_driver(actor, obj, as_visible_to = nil)
      # verbosity mappings

      id_keys = [ :type, :url_path ]
      id_keys << :id if obj.respond_to?(:id)
      h = obj.to_hash(actor, { verbosity: :id })
      assert_equal id_keys.sort, h.keys.sort
      if obj.respond_to?(:id)
        assert_equal obj.id, h[:id]
      end
      assert_equal obj.class.name, h[:type]

      min_keys = id_keys | [ :code ]
      min_keys << :permissions if obj.respond_to?(:permission?)
      h = obj.to_hash(actor, { verbosity: :minimal })
      assert_equal min_keys.sort, h.keys.sort
      assert_equal obj.code, h[:code]

      std_keys = min_keys | [ :name ]
      h = obj.to_hash(actor, { verbosity: :standard })
      assert_equal std_keys.sort, h.keys.sort
      assert_equal obj.name, h[:name]

      vrb_keys = std_keys | [ ]
      h = obj.to_hash(actor, { verbosity: :verbose })
      assert_equal vrb_keys.sort, h.keys.sort

      cmp_keys = vrb_keys | [ ]
      h = obj.to_hash(actor, { verbosity: :complete })
      assert_equal cmp_keys.sort, h.keys.sort

      h = obj.to_hash(actor, { verbosity: :ignore })
      assert_equal id_keys.sort, h.keys.sort

      # customize keys lists

      c_keys = id_keys | [ :code ]
      h = obj.to_hash(actor, { verbosity: :id, include: [ :code ] })
      assert_equal c_keys.sort, h.keys.sort

      c_keys = id_keys | [ :code ]
      h = obj.to_hash(actor, { verbosity: :minimal, only: [ :code ] })
      assert_equal c_keys.sort, h.keys.sort

      c_keys = min_keys - [ :code ]
      h = obj.to_hash(actor, { verbosity: :minimal, except: [ :code ] })
      assert_equal c_keys.sort, h.keys.sort

      # as visible to

      if as_visible_to
        v_keys = min_keys | [ ]
        h = obj.to_hash(actor, { verbosity: :minimal, as_visible_to: as_visible_to })
        assert_equal v_keys.sort, h.keys.sort
      end

      # return the permissions

      if obj.respond_to?(:permission?)
        h = obj.to_hash(actor, { verbosity: :minimal })
        h[:permissions]
      else
        nil
      end
    end

    def test_base_access
      u1_50 = User.new('u1_50', 50)
      u2_120 = User.new('u2_120', 120)
      u3_145 = User.new('u3_145', 145)

      a1_10 = BaseAsset.new('a1_10', 10)
      a2_80 = BaseAsset.new('a2_80', 80)
      a3_110 = BaseAsset.new('a3_110', 110)
      a4_200 = BaseAsset.new('a4_200', 200)

      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u1_50, a1_10)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a2_80)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u2_120, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u2_120, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u2_120, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u2_120, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u3_145, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u3_145, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u3_145, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u3_145, a4_200)
      assert_equal xp, p
    end

    def test_override_access
      u1_50 = User.new('u1_50', 50)
      u2_120 = User.new('u2_120', 120)
      u3_145 = User.new('u3_145', 145)

      a1_10 = OverrideAsset.new('a1_10', 10)
      a2_80 = OverrideAsset.new('a2_80', 80)
      a3_110 = OverrideAsset.new('a3_110', 110)
      a4_200 = OverrideAsset.new('a4_200', 200)

      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a1_10)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a2_80)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u1_50, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u2_120, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u2_120, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil }
      p = to_hash_driver(u2_120, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil }
      p = to_hash_driver(u2_120, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u3_145, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u3_145, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil }
      p = to_hash_driver(u3_145, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: :ok, destroy: nil }
      p = to_hash_driver(u3_145, a4_200)
      assert_equal xp, p
    end

    def test_extend_access
      u1_50 = User.new('u1_50', 50)
      u2_120 = User.new('u2_120', 120)
      u3_145 = User.new('u3_145', 145)

      a1_10 = ExtendAsset.new('a1_10', 10)
      a2_80 = ExtendAsset.new('a2_80', 80)
      a3_110 = ExtendAsset.new('a3_110', 110)
      a4_200 = ExtendAsset.new('a4_200', 200)

      xp = { read: :ok, write: :ok, destroy: nil, instance_op: nil }
      p = to_hash_driver(u1_50, a1_10)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil, instance_op: nil }
      p = to_hash_driver(u1_50, a2_80)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil, instance_op: nil }
      p = to_hash_driver(u1_50, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil, instance_op: nil }
      p = to_hash_driver(u1_50, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: :ok, destroy: nil, instance_op: nil }
      p = to_hash_driver(u2_120, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil, instance_op: nil }
      p = to_hash_driver(u2_120, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: :ok, destroy: nil, instance_op: nil }
      p = to_hash_driver(u2_120, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil, instance_op: nil }
      p = to_hash_driver(u2_120, a4_200)
      assert_equal xp, p

      xp = { read: :ok, write: nil, destroy: nil, instance_op: :ok }
      p = to_hash_driver(u3_145, a1_10)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil, instance_op: :ok }
      p = to_hash_driver(u3_145, a2_80)
      assert_equal xp, p
      xp = { read: :ok, write: nil, destroy: nil, instance_op: :ok }
      p = to_hash_driver(u3_145, a3_110)
      assert_equal xp, p
      xp = { read: nil, write: nil, destroy: nil, instance_op: nil }
      p = to_hash_driver(u3_145, a4_200)
      assert_equal xp, p
    end
  end
end
