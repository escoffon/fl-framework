require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

class Wrapper
  include Fl::Framework::TextSearchHelper

  def self.attribute_names()
    [ 'one', 'two' ]
  end
end

class Relation
  attr_reader :where_args
  
  def where(*args)
    @where_args = args
    self
  end

  attr_reader :select_args
  
  def select(*args)
    @select_args = args
    self
  end

  attr_reader :order_args
  
  def order(*args)
    @order_args = args
    self
  end
end

RSpec.describe Fl::Framework::TextSearchHelper, type: :helper do
  describe '.tokenize_query_string' do
    it 'should parse a list of simple words' do
      expect(Wrapper.tokenize_query_string('one two')).to eql([ [ :word, 'one' ], [ :word, 'two' ] ])
      expect(Wrapper.tokenize_query_string('one      two')).to eql([ [ :word, 'one' ], [ :word, 'two' ] ])
    end

    it 'should parse quoted strings' do
      qs = Wrapper.tokenize_query_string('"one two"   "two    three"')
      expect(qs).to eql([ [ :quoted, 'one two' ], [ :quoted, 'two three' ] ])

      qs = Wrapper.tokenize_query_string('"    one     two     "   "   two    three   "')
      expect(qs).to eql([ [ :quoted, 'one two' ], [ :quoted, 'two three' ] ])

      qs = Wrapper.tokenize_query_string('"one - two"')
      expect(qs).to eql([ [ :quoted, 'one - two' ] ])

      qs = Wrapper.tokenize_query_string('"one      -      two      "')
      expect(qs).to eql([ [ :quoted, 'one - two' ] ])

      qs = Wrapper.tokenize_query_string('"one OR two"')
      expect(qs).to eql([ [ :quoted, 'one OR two' ] ])

      expect do
        qs = Wrapper.tokenize_query_string('one"two"')
      end.to raise_error(Fl::Framework::TextSearchHelper::MalformedQuery)

      expect do
        qs = Wrapper.tokenize_query_string('AROUND("4")')
      end.to raise_error(Fl::Framework::TextSearchHelper::MalformedQuery)
    end

    it 'should parse the - (and !) operator' do
      qs = Wrapper.tokenize_query_string('one - two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one ! two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string(' - two')
      expect(qs).to eql([ [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string(' ! two')
      expect(qs).to eql([ [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('-two')
      expect(qs).to eql([ [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string(' !two')
      expect(qs).to eql([ [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one -two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one !two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one- two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one! two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one-two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one!two')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('"one one" - "two two"')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('"one one" ! "two two"')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string(' - "two two"')
      expect(qs).to eql([ [ :minus ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string(' ! "two two"')
      expect(qs).to eql([ [ :minus ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string('-"two two"')
      expect(qs).to eql([ [ :minus ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('!"two two"')
      expect(qs).to eql([ [ :minus ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string('one -"two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('one !"two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :minus ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string('"one one"- two')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('"one one"! two')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('"one one"-"two two"')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('"one one"!"two two"')
      expect(qs).to eql([ [ :quoted, 'one one' ], [ :minus ], [ :quoted, 'two two' ] ])
    end

    it 'should parse the OR (and |) operator' do
      qs = Wrapper.tokenize_query_string('one OR two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one | two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one|two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one or two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('oneOR two')
      expect(qs).to eql([ [ :word, 'oneOR' ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one ORtwo')
      expect(qs).to eql([ [ :word, 'one' ], [ :word, 'ORtwo' ] ])

      qs = Wrapper.tokenize_query_string('one OR "two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('one|"two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string('one OR -two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one | -two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one|-two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one|!two')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ], [ :minus ], [ :word, 'two' ] ])
    end

    it 'should parse the AND (and &) operator' do
      qs = Wrapper.tokenize_query_string('one AND two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one & two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one&two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one and two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one AND "two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :quoted, 'two two' ] ])
      qs = Wrapper.tokenize_query_string('one & "two two"')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :quoted, 'two two' ] ])

      qs = Wrapper.tokenize_query_string('one AND -two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one & -two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one &-two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one &!two')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :word, 'two' ] ])
    end

    it 'should parse the AROUND(n) (and <n>) operator' do
      qs = Wrapper.tokenize_query_string('AROUND(4)')
      expect(qs).to eql([ [ :around, 4 ] ])
      qs = Wrapper.tokenize_query_string('<4>')
      expect(qs).to eql([ [ :around, 4 ] ])

      qs = Wrapper.tokenize_query_string('one AROUND(4) two')
      expect(qs).to eql([ [ :word, 'one' ], [ :around, 4 ], [ :word, 'two' ] ])
      qs = Wrapper.tokenize_query_string('one <4> two')
      expect(qs).to eql([ [ :word, 'one' ], [ :around, 4 ], [ :word, 'two' ] ])

      qs = Wrapper.tokenize_query_string('one <-> two')
      expect(qs).to eql([ [ :word, 'one' ], [ :around, 1 ], [ :word, 'two' ] ])

      expect do
        qs = Wrapper.tokenize_query_string('one AROUND( 4) two')
      end.to raise_error(Fl::Framework::TextSearchHelper::MalformedQuery)

      expect do
        qs = Wrapper.tokenize_query_string('one AROUND(4 ) two')
      end.to raise_error(Fl::Framework::TextSearchHelper::MalformedQuery)

      expect do
        qs = Wrapper.tokenize_query_string('one AROUND(4a) two')
      end.to raise_error(Fl::Framework::TextSearchHelper::MalformedQuery)
    end

    it 'should parse ( and )' do
      qs = Wrapper.tokenize_query_string('one AND (two OR three)')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :open ], [ :word, 'two' ],
                          [ :or ], [ :word, 'three' ], [ :close ] ])

      qs = Wrapper.tokenize_query_string('one   AND  (  "two    two"    OR    three )')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :open ], [ :quoted, 'two two' ],
                          [ :or ], [ :word, 'three' ], [ :close ] ])

      qs = Wrapper.tokenize_query_string('one AND -(two OR three)')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :open ], [ :word, 'two' ],
                          [ :or ], [ :word, 'three' ], [ :close ] ])

      qs = Wrapper.tokenize_query_string('one AND - (two OR three)')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :open ], [ :word, 'two' ],
                          [ :or ], [ :word, 'three' ], [ :close ] ])

      qs = Wrapper.tokenize_query_string('one AND - (two OR (three AND four))')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ], [ :minus ], [ :open ], [ :word, 'two' ],
                          [ :or ], [ :open ], [ :word, 'three' ], [ :and ], [ :word, 'four' ],
                          [ :close ], [ :close ] ])
    end

    it 'should handle edge conditions' do
      qs = Wrapper.tokenize_query_string('one AND')
      expect(qs).to eql([ [ :word, 'one' ], [ :and ] ])

      qs = Wrapper.tokenize_query_string('one OR')
      expect(qs).to eql([ [ :word, 'one' ], [ :or ] ])

      qs = Wrapper.tokenize_query_string('one "two      two     ')
      expect(qs).to eql([ [ :word, 'one' ], [ :quoted, 'two two' ] ])
    end
  end

  describe '.pg_query_text' do
    it 'should convert a list of simple words' do
      qs = Wrapper.tokenize_query_string('one two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & two')
    end

    it 'should convert quoted strings' do
      qs = Wrapper.tokenize_query_string('"one two"   "two    three"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "two") & ("two" <-> "three")')

      qs = Wrapper.tokenize_query_string('"one - two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "-" <-> "two")')

      qs = Wrapper.tokenize_query_string('"one OR two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "OR" <-> "two")')
    end

    it 'should convert the - operator' do
      qs = Wrapper.tokenize_query_string('one - two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !two')

      qs = Wrapper.tokenize_query_string(' - two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:!two')
      qs = Wrapper.tokenize_query_string('-two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:!two')

      qs = Wrapper.tokenize_query_string('one -two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !two')
      qs = Wrapper.tokenize_query_string('one- two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !two')
      qs = Wrapper.tokenize_query_string('one-two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !two')

      qs = Wrapper.tokenize_query_string('"one one" - "two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "one") & !("two" <-> "two")')

      qs = Wrapper.tokenize_query_string(' - "two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:!("two" <-> "two")')
      qs = Wrapper.tokenize_query_string('-"two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:!("two" <-> "two")')

      qs = Wrapper.tokenize_query_string('one -"two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !("two" <-> "two")')

      qs = Wrapper.tokenize_query_string('"one one"- two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "one") & !two')

      qs = Wrapper.tokenize_query_string('"one one"-"two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:("one" <-> "one") & !("two" <-> "two")')
    end

    it 'should convert the OR operator' do
      qs = Wrapper.tokenize_query_string('one OR two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one | two')

      qs = Wrapper.tokenize_query_string('one or two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one | two')

      qs = Wrapper.tokenize_query_string('oneOR two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:oneOR & two')

      qs = Wrapper.tokenize_query_string('one ORtwo')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & ORtwo')

      qs = Wrapper.tokenize_query_string('one OR "two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one | ("two" <-> "two")')

      qs = Wrapper.tokenize_query_string('one OR -two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one | !two')
    end

    it 'should convert the AND operator' do
      qs = Wrapper.tokenize_query_string('one AND two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & two')

      qs = Wrapper.tokenize_query_string('one and two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & two')

      qs = Wrapper.tokenize_query_string('one AND "two two"')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & ("two" <-> "two")')

      qs = Wrapper.tokenize_query_string('one AND -two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !two')
    end

    it 'should convert the AROUND(n) operator' do
      qs = Wrapper.tokenize_query_string('one AROUND(4) two')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one <4> two')

      qs = Wrapper.tokenize_query_string('four - (one AROUND(4) two)')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:four & !(one <4> two)')

      qs = Wrapper.tokenize_query_string('four -(one AROUND(4) two)')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:four & !(one <4> two)')
    end

    it 'should convert ( and )' do
      qs = Wrapper.tokenize_query_string('one AND (two OR three)')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & (two | three)')

      qs = Wrapper.tokenize_query_string('one   AND  (  "two    two"    OR    three )')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & (("two" <-> "two") | three)')

      qs = Wrapper.tokenize_query_string('one AND -(two OR three)')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !(two | three)')

      qs = Wrapper.tokenize_query_string('one AND - (two OR three)')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !(two | three)')

      qs = Wrapper.tokenize_query_string('one AND - (two OR (three AND four))')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !(two | (three & four))')

      qs = Wrapper.tokenize_query_string('one AND - ("two two" OR (three AND four))')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & !(("two" <-> "two") | (three & four))')
    end

    it 'should handle edge conditions' do
      qs = Wrapper.tokenize_query_string('one AND')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one &')

      qs = Wrapper.tokenize_query_string('one OR')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one |')

      qs = Wrapper.tokenize_query_string('one "two      two     ')
      expect(Wrapper.pg_query_text(qs)).to eql('pg:one & ("two" <-> "two")')
    end
  end

  describe '.pg_query_string' do
    it 'should convert a query string' do
      qs = 'one two'
      expect(Wrapper.pg_query_string(qs)).to eql('one & two')

      qs = '"one two"   "two    three"'
      expect(Wrapper.pg_query_string(qs)).to eql('("one" <-> "two") & ("two" <-> "three")')

      qs = 'one - two'
      expect(Wrapper.pg_query_string(qs)).to eql('one & !two')

      qs = 'one OR -two'
      expect(Wrapper.pg_query_string(qs)).to eql('one | !two')

      qs = 'one AND "two two"'
      expect(Wrapper.pg_query_string(qs)).to eql('one & ("two" <-> "two")')

      qs = 'four -(one AROUND(4) two)'
      expect(Wrapper.pg_query_string(qs)).to eql('four & !(one <4> two)')

      qs = 'one AND -(two OR (three AND four))'
      expect(Wrapper.pg_query_string(qs)).to eql('one & !(two | (three & four))')

      qs = 'one "two      two     '
      expect(Wrapper.pg_query_string(qs)).to eql('one & ("two" <-> "two")')
    end

    it "should return a pg: query string as is" do
      expect(Wrapper.pg_query_string('pg:one & two')).to eql('one & two')
    end
  end

  describe ".pg_rank" do
    it "should generate correct defaults" do
      rq = Wrapper.pg_rank('mytsv', 'pg:one & two')
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('one & two'), 16)")
    end

    it "should convert the query" do
      rq = Wrapper.pg_rank('mytsv', 'one AND two')
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('one & two'), 16)")

      rq = Wrapper.pg_rank('mytsv', 'one two')
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('one & two'), 16)")
    end

    it "should accept the :_f option" do
      rq = Wrapper.pg_rank('mytsv', 'pg:(one | two) & four', _f: 'ts_rank_cd')
      expect(rq).to eql("ts_rank_cd(mytsv, to_tsquery('(one | two) & four'), 16)")

      rq = Wrapper.pg_rank('mytsv', 'pg:(one | two) & four', _f: :ts_rank_cd)
      expect(rq).to eql("ts_rank_cd(mytsv, to_tsquery('(one | two) & four'), 16)")

      rq = Wrapper.pg_rank('mytsv', 'pg:(one | two) & four', _f: 'ts_rank')
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('(one | two) & four'), 16)")

      rq = Wrapper.pg_rank('mytsv', 'pg:(one | two) & four', _f: :ts_rank)
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('(one | two) & four'), 16)")
    end

    it "should accept the :_w option" do
      rq = Wrapper.pg_rank('mytsv', 'pg:one & two', _w: { A: 1.0, B: 0.5, D: 0.1 })
      expect(rq).to eql("ts_rank(array[0.1, 0, 0.5, 1.0], mytsv, to_tsquery('one & two'), 16)")

      rq = Wrapper.pg_rank('mytsv', 'pg:one & two', _w: { A: 1.0, C: 0.1 })
      expect(rq).to eql("ts_rank(array[0, 0.1, 0, 1.0], mytsv, to_tsquery('one & two'), 16)")
    end

    it "should accept the :_n option" do
      rq = Wrapper.pg_rank('mytsv', 'pg:one & two', _n: 4)
      expect(rq).to eql("ts_rank(mytsv, to_tsquery('one & two'), 4)")
    end

    it "should accept all options together" do
      rq = Wrapper.pg_rank('mytsv', 'pg:one & two', _w: { A: 1.0, B: 0.5, D: 0.1 }, _n: 8, _f: :ts_rank_cd)
      expect(rq).to eql("ts_rank_cd(array[0.1, 0, 0.5, 1.0], mytsv, to_tsquery('one & two'), 8)")
    end
  end
  
  describe ".pg_parse_order_option" do
    it 'should return simple clauses if rank is not present' do
      o = Wrapper.pg_parse_order_option({ order: "id ASC" })
      expect(o).to eql([ [ 'id ASC' ], nil ])

      o = Wrapper.pg_parse_order_option({ order: "id ASC, updated_at DESC" })
      expect(o).to eql([ [ 'id ASC', 'updated_at DESC' ], nil ])

      o = Wrapper.pg_parse_order_option({ order: [ "id ASC", "updated_at DESC" ] })
      expect(o).to eql([ [ 'id ASC', 'updated_at DESC' ], nil ])
    end

    it 'should return rank clauses if rank is present' do
      o = Wrapper.pg_parse_order_option({ order: "id ASC, rank", rank: { tsv: 'mytsv' } }, 'pg:one | two')
      expect(o).to eql([ [ "id ASC", "ts_rank(mytsv, to_tsquery('pg:one | two'), 16) DESC" ],
                         "ts_rank(mytsv, to_tsquery('pg:one | two'), 16)" ])

      o = Wrapper.pg_parse_order_option({ order: "id ASC, rank ASC", rank: { tsv: 'mytsv' } }, 'pg:one | two')
      expect(o).to eql([ [ "id ASC", "ts_rank(mytsv, to_tsquery('pg:one | two'), 16) ASC" ],
                         "ts_rank(mytsv, to_tsquery('pg:one | two'), 16)" ])
    end

    it 'should accept rank options when rank is present' do
      o = Wrapper.pg_parse_order_option({
                                          order: "id ASC, rank",
                                          rank: {
                                            tsv: 'mytsv',
                                            _f: 'ts_rank_cd',
                                            _w: { A: 1.0, C: 0.2 },
                                            _n: 8
                                          }
                                        }, 'pg:one | two')
      expect(o).to eql([ [ "id ASC", "ts_rank_cd(array[0, 0.2, 0, 1.0], mytsv, to_tsquery('pg:one | two'), 8) DESC" ],
                         "ts_rank_cd(array[0, 0.2, 0, 1.0], mytsv, to_tsquery('pg:one | two'), 8)" ])
    end
  end

  describe ".pg_where" do
    it "should use default options" do
      w = Wrapper.pg_where('mydoc', 'mytsv', 'pg:one | two')
      expect(w).to eql("(mytsv @@ to_tsquery('one | two'))")
    end

    it "should handle a null tsvector name" do
      w = Wrapper.pg_where('mydoc', nil, 'pg:one | two')
      expect(w).to eql("(to_tsvector(mydoc) @@ to_tsquery('one | two'))")
    end

    it "should handle a null document name" do
      w = Wrapper.pg_where(nil, 'mytsv', 'pg:one | two')
      expect(w).to eql("(mytsv @@ to_tsquery('one | two'))")
    end

    it "should convert a query string" do
      w = Wrapper.pg_where(nil, 'mytsv', 'one two')
      expect(w).to eql("(mytsv @@ to_tsquery('one & two'))")
    end

    it "should add a configuration parameter if one is given" do
      w = Wrapper.pg_where(nil, 'mytsv', 'pg:one | two', 'pg_catalog.simple')
      expect(w).to eql("(mytsv @@ to_tsquery('pg_catalog.simple', 'one | two'))")

      w = Wrapper.pg_where(nil, 'mytsv', 'pg:one | two', 'simple')
      expect(w).to eql("(mytsv @@ to_tsquery('pg_catalog.simple', 'one | two'))")
    end
  end

  describe ".add_full_text_query" do
    it "should use default options" do
      q = Relation.new
      qr = Wrapper.add_full_text_query(q, 'mydoc', 'mytsv', 'pg:one | two')
      expect(qr.where_args).to eql([ "(mytsv @@ to_tsquery('one | two'))" ])
      expect(qr.select_args).to be_nil
    end

    it "should handle a null tsvector name" do
      q = Relation.new
      qr = Wrapper.add_full_text_query(q, 'mydoc', nil, 'pg:one | two')
      expect(qr.where_args).to eql([ "(to_tsvector(mydoc) @@ to_tsquery('one | two'))" ])
      expect(qr.select_args).to be_nil
    end

    it "should handle a null document name" do
      q = Relation.new
      qr = Wrapper.add_full_text_query(q, nil, 'mytsv', 'pg:one | two')
      expect(qr.where_args).to eql([ "(mytsv @@ to_tsquery('one | two'))" ])
      expect(qr.select_args).to be_nil
    end

    it "should convert a query string" do
      q = Relation.new
      qr = Wrapper.add_full_text_query(q, nil, 'mytsv', 'one two')
      expect(qr.where_args).to eql([ "(mytsv @@ to_tsquery('one & two'))" ])
      expect(qr.select_args).to be_nil
    end

    it "should add a headline column" do
      q = Relation.new

      qr = Wrapper.add_full_text_query(q, 'mydoc', 'mytsv', 'one two', with_headline: true)
      expect(qr.where_args).to eql([ "(mytsv @@ to_tsquery('one & two'))" ])
      expect(qr.select_args).to eql([ [ "one", "two", "ts_headline(mydoc, to_tsquery('one & two')) AS headline" ] ])

      qr = Wrapper.add_full_text_query(q, 'mydoc', 'mytsv', 'one two', with_headline: 'myhl')
      expect(qr.where_args).to eql([ "(mytsv @@ to_tsquery('one & two'))" ])
      expect(qr.select_args).to eql([ [ "one", "two", "ts_headline(mydoc, to_tsquery('one & two')) AS myhl" ] ])
    end
  end

  describe ".pg_headline_select_item" do
    it "should generate with defaults" do
      h = Wrapper.pg_headline_select_item('mydoc', 'pg:one & two')
      expect(h).to eql("ts_headline(mydoc, to_tsquery('one & two')) AS headline")
    end

    it "should process the query string" do
      h = Wrapper.pg_headline_select_item('mydoc', 'one two')
      expect(h).to eql("ts_headline(mydoc, to_tsquery('one & two')) AS headline")

      h = Wrapper.pg_headline_select_item('mydoc', 'one OR two')
      expect(h).to eql("ts_headline(mydoc, to_tsquery('one | two')) AS headline")
    end

    it "should use a custom headline column name" do
      h = Wrapper.pg_headline_select_item('mydoc', 'pg:one | two', 'myhline')
      expect(h).to eql("ts_headline(mydoc, to_tsquery('one | two')) AS myhline")
    end

    it "should use a configuration name" do
      h = Wrapper.pg_headline_select_item('mydoc', 'pg:one | two', 'myhline', 'mycfg')
      expect(h).to eql("ts_headline(mycfg, mydoc, to_tsquery('one | two')) AS myhline")

      h = Wrapper.pg_headline_select_item('mydoc', 'pg:one | two', 'myhline', "'mycfg'")
      expect(h).to eql("ts_headline('mycfg', mydoc, to_tsquery('one | two')) AS myhline")
    end

    it "should generate configuration options" do
      h = Wrapper.pg_headline_select_item('mydoc', 'pg:one & two', nil, nil, {
                                            StartSel: '<<', StopSel: '>>', MaxWords: 20
                                          })
      expect(h).to eql("ts_headline(mydoc, to_tsquery('one & two'), 'StartSel = <<, StopSel = >>, MaxWords = 20') AS headline")
    end
  end

  describe ".add_rank_order" do
    it "should build the clause properly" do
      q = Relation.new
      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:one & two')
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('one & two'), 16) DESC" ])
    end

    it "should convert the query" do
      q = Relation.new

      qr = Wrapper.add_rank_order(q, 'mytsv', 'one AND two')
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('one & two'), 16) DESC" ])

      qr = Wrapper.add_rank_order(q, 'mytsv', 'one two')
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('one & two'), 16) DESC" ])
    end

    it "should accept the :_f option" do
      q = Relation.new

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:(one | two) & four', _f: 'ts_rank_cd')
      expect(qr.order_args).to eql([ "ts_rank_cd(mytsv, to_tsquery('(one | two) & four'), 16) DESC" ])

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:(one | two) & four', _f: :ts_rank_cd)
      expect(qr.order_args).to eql([ "ts_rank_cd(mytsv, to_tsquery('(one | two) & four'), 16) DESC" ])

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:(one | two) & four', _f: 'ts_rank')
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('(one | two) & four'), 16) DESC" ])

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:(one | two) & four', _f: :ts_rank)
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('(one | two) & four'), 16) DESC" ])
    end

    it "should accept the :_w option" do
      q = Relation.new

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:one & two', _w: { A: 1.0, B: 0.5, D: 0.1 })
      expect(qr.order_args).to eql([ "ts_rank(array[0.1, 0, 0.5, 1.0], mytsv, to_tsquery('one & two'), 16) DESC" ])

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:one & two', _w: { A: 1.0, C: 0.1 })
      expect(qr.order_args).to eql([ "ts_rank(array[0, 0.1, 0, 1.0], mytsv, to_tsquery('one & two'), 16) DESC" ])
    end

    it "should accept the :_n option" do
      q = Relation.new

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:one & two', _n: 4)
      expect(qr.order_args).to eql([ "ts_rank(mytsv, to_tsquery('one & two'), 4) DESC" ])
    end

    it "should accept all options together" do
      q = Relation.new

      qr = Wrapper.add_rank_order(q, 'mytsv', 'pg:one & two', _w: { A: 1.0, B: 0.5, D: 0.1 }, _n: 8, _f: :ts_rank_cd)
      expect(qr.order_args).to eql([ "ts_rank_cd(array[0.1, 0, 0.5, 1.0], mytsv, to_tsquery('one & two'), 8) DESC" ])
    end
  end
end
