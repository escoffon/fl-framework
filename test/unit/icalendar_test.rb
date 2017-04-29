require 'test_helper'

module Fl::Framework::Test
  class IcalendarTest < TestCase
    # The local timezone for all tests is America/Los_Angeles

    def setup()
      @cur_tz = Time.zone
      Time.zone = 'America/Los_Angeles'
    end

    def teardown()
      Time.zone = @cur_tz
    end

    def today(tz = nil)
      tzz = if tz.is_a?(String)
              ActiveSupport::TimeZone.new(tz)
            elsif tz.nil?
              Time.zone
            else
              tz
            end
      t = tzz.now
      sprintf('%04d%02d%02d', t.year, t.month, t.day)
    end

    test "datetime to time" do
      t = Time.now
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(t).to_i

      cur_tz = Time.zone

      # Time.local does not seem to use the current timezone; instead, it seems to get the local timezone info
      # based on the host's timezone settings, which may be different from the test case's since the test case
      # sets the Time timezone to America/Los_Angeles.
      # So there is a bit of an inconsistencty between the time returned by Time.local and the ones returned
      # by the ICalendar stuff.

      t = Time.utc(2014, 1, 20, 10, 20, 30)
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(t).to_i
      assert_equal t.to_i - cur_tz.utc_offset, Fl::Framework::Core::Icalendar.datetime_to_time('20140120T102030').to_i
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140120T102030')
      assert_equal t.to_i - cur_tz.utc_offset, Fl::Framework::Core::Icalendar.datetime_to_time(dt).to_i

      t = Time.utc(2014, 1, 20, 10, 20, 30)
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(t).to_i
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time('20140120T102030Z').to_i
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140120T102030Z')
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(dt).to_i
      Time.zone = cur_tz

      Time.zone = 'Europe/Rome'
      t = Time.zone.parse('2014-01-20 10:20:30')
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(t).to_i
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time("TZID=Europe/Rome:20140120T102030").to_i
      dt = Fl::Framework::Core::Icalendar::Datetime.new("TZID=Europe/Rome:20140120T102030")
      assert_equal t.to_i, Fl::Framework::Core::Icalendar.datetime_to_time(dt).to_i
      Time.zone = cur_tz
    end

    test "property parsing" do
      x = {
        :name => 'SIMPLE',
        :params => {},
        :value => 'value for simple'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('SIMPLE:value for simple')
      assert_equal x, r
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('simple:value for simple')
      assert_equal x, r

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for PAR1'
        },
        :value => 'value for name'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('NAME;PAR1=value for PAR1:value for name')
      assert_equal x, r
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;PAR1="value for PAR1":value for name')
      assert_equal x, r

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for par1'
        },
        :value => 'value for name'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('NAME;par1=value for par1:value for name')
      assert_equal x, r
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;par1="value for par1":value for name')
      assert_equal x, r

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for par1',
          :PAR2 => 'value for par2'
        },
        :value => 'value for name'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('NAME;par2=value for par2;par1=value for par1:value for name')
      assert_equal x, r
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;par1="value for par1";par2="value for par2":value for name')
      assert_equal x, r

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value : for par1',
          :PAR2 => 'value for ; par2'
        },
        :value => 'value for name'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;par1="value : for par1";par2="value for ; par2":value for name')
      assert_equal x, r

      x = {
        :name => 'NAME',
        :params => {
          :VALUE => 'DATE-TIME',
          :PAR2 => 'value for ; par2'
        },
        :type => 'DATE-TIME',
        :value => 'value for name'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;VALUE=DATE-TIME;par2="value for ; par2":value for name')
      assert_equal x, r
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('name;value=date-time;par2="value for ; par2":value for name')
      assert_equal x, r 

      x = {
        :name => 'GEO',
        :params => {},
        :value => '37.386013;-122.082932'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('GEO:37.386013;-122.082932')
      assert_equal x, r

      x = {
        :name => 'ATTACH',
        :params => {
          :FMTTYPE => 'application/postscript'
        },
        :value => 'ftp://example.com/pub/reports/r-960812.ps'
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('ATTACH;FMTTYPE=application/postscript:ftp://example.com/pub/reports/r-960812.ps')
      assert_equal x, r

      x = {
        :name => 'PNAME',
        :params => {
          :ONE => 'one:two'
        },
        :value => "A, B\nC: D; \\E"
      }
      r = Fl::Framework::Core::Icalendar::Property::Base.parse('PNAME;ONE="one:two":A\, B\nC\: D\; \\\\E')
      assert_equal x, r
    end

    test "property creation" do
      x = {
        :name => 'SIMPLE',
        :params => {},
        :value => 'value for simple'
      }
      s = 'SIMPLE:value for simple'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for PAR1'
        },
        :value => 'value for name'
      }
      s = 'NAME;PAR1=value for PAR1:value for name'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for par1'
        },
        :value => 'value for name'
      }
      s = 'NAME;PAR1=value for par1:value for name'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s

      x = {
        :name => 'NAME',
        :params => {
          :PAR1 => 'value for par1',
          :PAR2 => 'value for par2'
        },
        :value => 'value for name'
      }
      s = 'NAME;PAR1=value for par1;PAR2=value for par2:value for name'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s

      x = {
        :name => 'name',
        :params => {
          :par1 => 'value : for par1',
          :PAR2 => 'value for ; par2'
        },
        :value => 'value for name'
      }
      s = 'NAME;PAR1="value : for par1";PAR2="value for ; par2":value for name'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s

      x = {
        :name => 'name',
        :params => {
          :value => 'DATE',
          :PAR2 => 'value for ; par2'
        },
        :value => 'value for name'
      }
      s = 'NAME;VALUE=DATE;PAR2="value for ; par2":value for name'
      p1 = Fl::Framework::Core::Icalendar::Property::Base.new(s)
      p2 = Fl::Framework::Core::Icalendar::Property::Base.new(x)
      assert_equal s, p1.to_s
      assert_equal s, p2.to_s
      assert_equal 'DATE', p1.type
      assert_equal 'DATE', p2.type
    end

    test "property accessors" do
      p = Fl::Framework::Core::Icalendar::Property::Base.new()
      p.name = 'name'
      p.set_parameter(:par1, 'value : for par1')
      p.set_parameter(:value, 'DATE')
      p.value = 'value value here'

      assert_equal 'DATE', p.type
      assert_equal 'NAME;PAR1="value : for par1";VALUE=DATE:value value here', p.to_s

      p.type = 'date-time'
      assert_equal 'DATE-TIME', p.type
      assert_equal 'DATE-TIME', p.get_parameter('value')
      assert_equal 'NAME;PAR1="value : for par1";VALUE=DATE-TIME:value value here', p.to_s

      p.unset_parameter(:par1)
      assert_equal 'NAME;VALUE=DATE-TIME:value value here', p.to_s

      p.type = nil
      assert_equal 'NAME:value value here', p.to_s
    end

    test 'datetime management' do
      dt, tz = Fl::Framework::Core::Icalendar.split_datetime('20140112T102030')
      assert_nil tz
      assert_equal '20140112T102030', dt

      dt, tz = Fl::Framework::Core::Icalendar.split_datetime('20140112T102030Z')
      assert_equal 'UTC', tz
      assert_equal '20140112T102030', dt

      dt, tz = Fl::Framework::Core::Icalendar.split_datetime('TZID=America/Los_Angeles:20140112T102030')
      assert_equal 'America/Los_Angeles', tz
      assert_equal '20140112T102030', dt
    end

    test 'format datetime' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')

      assert_equal '20140110T102030', Fl::Framework::Core::Icalendar.format_datetime(dt)
      assert_equal '20140110', Fl::Framework::Core::Icalendar.format_date(dt)
      assert_equal '102030', Fl::Framework::Core::Icalendar.format_time(dt)

      tz_alt = ActiveSupport::TimeZone.new('America/New_York')
      dt_alt = dt.in_time_zone(tz_alt)

      assert_equal '20140110T132030', Fl::Framework::Core::Icalendar.format_datetime(dt_alt)
      assert_equal '20140110', Fl::Framework::Core::Icalendar.format_date(dt_alt)
      assert_equal '132030', Fl::Framework::Core::Icalendar.format_time(dt_alt)

      tz_base = ActiveSupport::TimeZone.new('Europe/Rome')
      dt = tz_base.parse('20140110T062030')

      assert_equal '20140110T062030', Fl::Framework::Core::Icalendar.format_datetime(dt)
      assert_equal '20140110', Fl::Framework::Core::Icalendar.format_date(dt)
      assert_equal '062030', Fl::Framework::Core::Icalendar.format_time(dt)

      tz_alt = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt_alt = dt.in_time_zone(tz_alt)

      assert_equal '20140109T212030', Fl::Framework::Core::Icalendar.format_datetime(dt_alt)
      assert_equal '20140109', Fl::Framework::Core::Icalendar.format_date(dt_alt)
      assert_equal '212030', Fl::Framework::Core::Icalendar.format_time(dt_alt)
    end

    test 'parse datetime' do
      Time.zone = 'America/Los_Angeles'

      dt = Fl::Framework::Core::Icalendar.parse('20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      assert_equal dt.to_i, dt_local.to_i
      assert_equal '20140110T102030', Fl::Framework::Core::Icalendar.format_datetime(dt_local)

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      assert_equal dt.to_i, dt_local.to_i
      assert_equal '20140110T102030', Fl::Framework::Core::Icalendar.format_datetime(dt_local)

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/New_York:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      assert_equal dt.to_i, dt_local.to_i
      assert_equal '20140110T072030', Fl::Framework::Core::Icalendar.format_datetime(dt_local)

      dt = Fl::Framework::Core::Icalendar.parse('20140110T102030Z')
      dt_local = dt.in_time_zone(Time.zone)
      assert_equal dt.to_i, dt_local.to_i
      assert_equal '20140110T022030', Fl::Framework::Core::Icalendar.format_datetime(dt_local)

      dt = Fl::Framework::Core::Icalendar.parse('TZID=Europe/Rome:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      assert_equal dt.to_i, dt_local.to_i
      assert_equal '20140110T012030', Fl::Framework::Core::Icalendar.format_datetime(dt_local)

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Menlo_Park:20140110T102030')
      assert dt.nil?
    end

    test 'timezone conversion' do
      dt = Fl::Framework::Core::Icalendar.in_time_zone('20140110T102030Z', 'America/Los_Angeles')
      assert_equal 'TZID=America/Los_Angeles:20140110T022030', dt
      d = Fl::Framework::Core::Icalendar.parse('20140110T102030Z')
      dt = Fl::Framework::Core::Icalendar.in_time_zone(d, 'America/Los_Angeles')
      assert_equal 'TZID=America/Los_Angeles:20140110T022030', dt

      dt = Fl::Framework::Core::Icalendar.in_time_zone('TZID=America/New_York:20140110T102030', 'America/Los_Angeles')
      assert_equal 'TZID=America/Los_Angeles:20140110T072030', dt

      d = Fl::Framework::Core::Icalendar.parse('TZID=America/New_York:20140110T102030')
      dt = Fl::Framework::Core::Icalendar.in_time_zone(d, 'America/Los_Angeles')
      assert_equal 'TZID=America/Los_Angeles:20140110T072030', dt

      s_5545 = 'TZID=America/New_York:20160210T102040'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_5545)
      ts_ny = dt.to_i
      ts_ca = dt.in_timezone('America/Los_Angeles').to_i
      assert_equal (180 * 60), ts_ca - ts_ny
      ts_co = dt.in_timezone(ActiveSupport::TimeZone.new('America/Denver')).to_i
      assert_equal (120 * 60), ts_co - ts_ny
    end

    test 'timezone validity' do
      assert Fl::Framework::Core::Icalendar::Datetime.valid_timezone?('UTC')
      assert Fl::Framework::Core::Icalendar::Datetime.valid_timezone?('America/Los_Angeles')
      assert !Fl::Framework::Core::Icalendar::Datetime.valid_timezone?('America/Menlo_Park')
    end

    test 'date type' do
      assert_equal 'NONE', Fl::Framework::Core::Icalendar.date_type('foo')
      assert_equal 'NONE', Fl::Framework::Core::Icalendar.date_type('fooZ')
      assert_equal 'NONE', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:foo')
      assert_equal 'NONE', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:1234T56')
      assert_equal 'NONE', Fl::Framework::Core::Icalendar.date_type('TZID=America/Menlo_Park:20140110')

      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('20140110T102030')
      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('20140110T1020')
      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('20140110T102030Z')
      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('20140110T1020Z')
      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110T102030')
      assert_equal 'DATE-TIME', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110T1020')

      assert_equal 'DATE', Fl::Framework::Core::Icalendar.date_type('20140110')
      assert_equal 'DATE', Fl::Framework::Core::Icalendar.date_type('20140110Z')
      assert_equal 'DATE', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110')

      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('102030')
      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('1020')
      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('102030Z')
      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('1020Z')
      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:102030')
      assert_equal 'TIME', Fl::Framework::Core::Icalendar.date_type('TZID=America/Los_Angeles:1020')
    end

    test "create datetime property" do
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
      assert_equal 'NAME', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_nil d.tzid
      assert_equal '20140110T102030', d.value

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', '20140110')
      assert_equal 'NAME2', d.name
      assert_equal 'DATE', d.get_parameter(:VALUE)
      assert_equal 'DATE', d.type
      assert_nil d.tzid
      assert_equal '20140110', d.value

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', 'TZID=America/Los_Angeles:20140110T102030')
      assert_equal 'NAME3', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'America/Los_Angeles', d.tzid
      assert_equal 'TZID=America/Los_Angeles:20140110T102030', d.value

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME4', '20140110T102030Z')
      assert_equal 'NAME4', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110T102030Z', d.value

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME5', '20140110Z')
      assert_equal 'NAME5', d.name
      assert_equal 'DATE', d.get_parameter(:VALUE)
      assert_equal 'DATE', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110Z', d.value

      dt = Fl::Framework::Core::Icalendar.parse('20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', dt)
      assert_equal 'NAME', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110T182030Z', d.value

      dt = Fl::Framework::Core::Icalendar.parse('20140110')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', dt)
      assert_equal 'NAME2', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110T080000Z', d.value

      dt = Fl::Framework::Core::Icalendar.parse('20140110')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', dt, { :VALUE => 'DATE' })
      assert_equal 'NAME2', d.name
      assert_equal 'DATE', d.get_parameter(:VALUE)
      assert_equal 'DATE', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110Z', d.value

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt)
      assert_equal 'NAME3', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'UTC', d.tzid
      assert_equal '20140110T182030Z', d.value

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/Los_Angeles' })
      assert_equal 'NAME3', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'America/Los_Angeles', d.tzid
      assert_equal 'TZID=America/Los_Angeles:20140110T102030', d.value

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York' })
      assert_equal 'NAME3', d.name
      assert_equal 'DATE-TIME', d.get_parameter(:VALUE)
      assert_equal 'DATE-TIME', d.type
      assert_equal 'America/New_York', d.tzid
      assert_equal 'TZID=America/New_York:20140110T132030', d.value

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York', :VALUE => 'DATE' })
      assert_equal 'NAME3', d.name
      assert_equal 'DATE', d.get_parameter(:VALUE)
      assert_equal 'DATE', d.type
      assert_equal 'America/New_York', d.tzid
      assert_equal 'TZID=America/New_York:20140110', d.value
    end

    test "update datetime property" do
      # timezone change from non-nil to non-nil: the datetime tracks the timezone

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.tzid = 'Europe/Rome'
      assert_equal 'Europe/Rome', d.tzid
      assert_equal 'TZID=Europe/Rome:20140110T162030', d.value

      # timezone change from non-nil to nil: the datetime switches to floating

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.tzid = nil
      assert_nil d.tzid
      assert_equal '20140110T102030', d.value

      # timezone change back to non-nil: the time is now anchored.

      d.tzid = 'Europe/Rome'
      assert_equal 'Europe/Rome', d.tzid
      assert_equal 'TZID=Europe/Rome:20140110T102030', d.value

      # timezone change from nil to non-nil: the time is anchored, but the datetime does not change

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
      assert_nil d.tzid
      assert_equal '20140110T102030', d.value
      d.tzid = 'America/New_York'
      assert_equal 'America/New_York', d.tzid
      assert_equal 'TZID=America/New_York:20140110T102030', d.value

      # value changes in the same timezone

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.value = '20140110T082030'
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T082030', d.value

      # value changes in the same timezone, switches to DATE

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.value = '20140112'
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE', d.type
      assert_equal 'TZID=America/New_York:20140112', d.value

      # value changes in a different timezone; tzid also changes

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.value = 'TZID=Europe/Rome:20140110T062030'
      assert_equal 'Europe/Rome', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=Europe/Rome:20140110T062030', d.value

      # value changes in the same timezone, switches to DATE

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T102030', d.value
      d.value = 'TZID=Europe/Rome:20140112'
      assert_equal 'Europe/Rome', d.tzid
      assert_equal 'DATE', d.type
      assert_equal 'TZID=Europe/Rome:20140112', d.value

      # value changes with a datetime

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T102030', d.value

      # (the current timezone is America/Los_Angeles)

      d.value = Fl::Framework::Core::Icalendar.parse('20140110T082030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T112030', d.value

      d.value = Fl::Framework::Core::Icalendar.parse('TZID=Europe/Rome:20140110T082030')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T022030', d.value

      # the type does not change: Time inputs convert to DATE-TIME only if not already defined

      d.value = Fl::Framework::Core::Icalendar.parse('20140110')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140110T030000', d.value

      d.value = Fl::Framework::Core::Icalendar.parse('TZID=Europe/Rome:20140110')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE-TIME', d.type
      assert_equal 'TZID=America/New_York:20140109T180000', d.value

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE', d.type
      assert_equal 'TZID=America/New_York:20140110', d.value

      d.value = Fl::Framework::Core::Icalendar.parse('TZID=Europe/Rome:20140110')
      assert_equal 'America/New_York', d.tzid
      assert_equal 'DATE', d.type
      assert_equal 'TZID=America/New_York:20140109', d.value
    end

    test "stringify datetime property" do
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
      assert_equal 'NAME;VALUE=DATE-TIME:20140110T102030', d.to_s

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', '20140110')
      assert_equal 'NAME2;VALUE=DATE:20140110', d.to_s

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', 'TZID=America/Los_Angeles:20140110T102030')
      assert_equal 'NAME3;VALUE=DATE-TIME:TZID=America/Los_Angeles:20140110T102030', d.to_s

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME4', '20140110T102030Z')
      assert_equal 'NAME4;VALUE=DATE-TIME:20140110T102030Z', d.to_s

      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME5', '20140110Z')
      assert_equal 'NAME5;VALUE=DATE:20140110Z', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME', dt)
      assert_equal 'NAME;VALUE=DATE-TIME:20140110T182030Z', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('20140110')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', dt)
      assert_equal 'NAME2;VALUE=DATE-TIME:20140110T080000Z', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('20140110')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME2', dt, { :VALUE => 'DATE' })
      assert_equal 'NAME2;VALUE=DATE:20140110Z', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt)
      assert_equal 'NAME3;VALUE=DATE-TIME:20140110T182030Z', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/Los_Angeles' })
      assert_equal 'NAME3;VALUE=DATE-TIME:TZID=America/Los_Angeles:20140110T102030', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York' })
      assert_equal 'NAME3;VALUE=DATE-TIME:TZID=America/New_York:20140110T132030', d.to_s

      dt = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      d = Fl::Framework::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York', :VALUE => 'DATE' })
      assert_equal 'NAME3;VALUE=DATE:TZID=America/New_York:20140110', d.to_s
    end

    test "datetime object" do
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140210T102030Z')
      assert dt.valid?
      assert_equal 'UTC', dt.timezone
      assert_equal '20140210', dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATETIME, dt.type
      h = { :TZID => 'UTC', :DATE => '20140210', :TIME => '102030' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal '20140210T102030Z', dt.to_s
      assert_equal h, dt.components
      tz  = ActiveSupport::TimeZone.new('UTC')
      t = tz.parse('20140210T102030')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse('20140210T102030')
      assert_equal t.to_i, dt.to_time.to_i

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140210Z')
      assert dt.valid?
      assert_equal 'UTC', dt.timezone
      assert_equal '20140210', dt.date
      assert_nil dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATE, dt.type
      h = { :TZID => 'UTC', :DATE => '20140210' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal '20140210Z', dt.to_s
      tz  = ActiveSupport::TimeZone.new('UTC')
      t = tz.parse('20140210T000000')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse('20140210T000000')
      assert_equal t.to_i, dt.to_time.to_i

      dt = Fl::Framework::Core::Icalendar::Datetime.new('102030Z')
      assert dt.valid?
      assert_equal 'UTC', dt.timezone
      assert_nil dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::TIME, dt.type
      h = { :TZID => 'UTC', :TIME => '102030' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal '102030Z', dt.to_s
      tz  = ActiveSupport::TimeZone.new('UTC')
      t = tz.parse(self.today(tz) + '102030')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse(self.today(tz) + '102030')
      assert_equal t.to_i, dt.to_time.to_i

      dt = Fl::Framework::Core::Icalendar::Datetime.new('TZID=America/New_York:20140210T102030')
      assert dt.valid?
      assert_equal 'America/New_York', dt.timezone
      assert_equal '20140210', dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATETIME, dt.type
      h = { :TZID => 'America/New_York', :DATE => '20140210', :TIME => '102030' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal 'TZID=America/New_York:20140210T102030', dt.to_s
      tz  = ActiveSupport::TimeZone.new('America/New_York')
      t = tz.parse('20140210T102030')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse('20140210T102030')
      assert_equal t.to_i, dt.to_time.to_i

      dt = Fl::Framework::Core::Icalendar::Datetime.new('TZID=America/New_York:20140210')
      assert dt.valid?
      assert_equal 'America/New_York', dt.timezone
      assert_equal '20140210', dt.date
      assert_nil dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATE, dt.type
      h = { :TZID => 'America/New_York', :DATE => '20140210' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal 'TZID=America/New_York:20140210', dt.to_s
      tz  = ActiveSupport::TimeZone.new('America/New_York')
      t = tz.parse('20140210T000000')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse('20140210T000000')
      assert_equal t.to_i, dt.to_time.to_i

      dt = Fl::Framework::Core::Icalendar::Datetime.new('TZID=America/New_York:102030')
      assert dt.valid?
      assert_equal 'America/New_York', dt.timezone
      assert_nil dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::TIME, dt.type
      h = { :TZID => 'America/New_York', :TIME => '102030' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal 'TZID=America/New_York:102030', dt.to_s
      tz  = ActiveSupport::TimeZone.new('America/New_York')
      t = tz.parse(self.today(tz) + '102030')
      assert_equal t.to_i, dt.to_time.to_i
      dt.timezone = 'America/Los_Angeles'
      tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
      t = tz.parse(self.today(tz) + '102030')
      assert_equal t.to_i, dt.to_time.to_i

      utc_tz = ActiveSupport::TimeZone.create('UTC')
      t = utc_tz.parse('2014-08-12 10:20:30')
      dt = Fl::Framework::Core::Icalendar::Datetime.new(t.to_i)
      assert dt.valid?
      assert_equal 'UTC', dt.timezone
      assert_equal '20140812', dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATETIME, dt.type
      h = { :TZID => 'UTC', :DATE => '20140812', :TIME => '102030' }
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal '20140812T102030Z', dt.to_s

      parsed = Fl::Framework::Core::Icalendar::Datetime.parse('TZID=America/New_York:20160416T102030')
      h = { TZID: 'America/New_York', DATE: '20160416', TIME: '102030' }
      assert_equal h, parsed
      dt = Fl::Framework::Core::Icalendar::Datetime.new(parsed)
      assert dt.valid?
      assert_equal 'America/New_York', dt.timezone
      assert_equal '20160416', dt.date
      assert_equal '102030', dt.time
      assert_equal Fl::Framework::Core::Icalendar::DATETIME, dt.type
      assert_equal h, dt.components
      assert_equal h, dt.to_hash
      assert_equal 'TZID=America/New_York:20160416T102030', dt.to_s
    end

    test "datetime validity" do
      # malformed

      dt = Fl::Framework::Core::Icalendar::Datetime.new('2014001T102030Z')
      assert !dt.well_formed?
      assert !dt.valid?

      # OK

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140110T102030Z')
      assert dt.well_formed?
      assert dt.valid?

      # month is 13

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141310T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      # day is 0

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140100T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      # check top day in month

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140131T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140132T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140228T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140229T102030Z')
      assert dt.well_formed?
      assert !dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20000228T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20000229T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20000230T102030Z')
      assert dt.well_formed?
      assert !dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('19000228T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('19000229T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140331T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140332T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140430T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140431T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140531T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140532T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140630T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140631T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140731T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140732T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140831T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140832T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140930T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140931T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141031T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141032T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141130T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141131T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141231T102030Z')
      assert dt.well_formed?
      assert dt.valid?
      dt = Fl::Framework::Core::Icalendar::Datetime.new('20141232T102030Z')
      assert dt.well_formed?
      assert !dt.valid?

      # hour is 24

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T242030Z')
      assert dt.well_formed?
      assert !dt.valid?

      # minute is 60

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T106030Z')
      assert dt.well_formed?
      assert !dt.valid?

      # second is 60 (and we ignore leap seconds)

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T102060Z')
      assert dt.well_formed?
      assert !dt.valid?

      # no second component: malformed

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T1020Z')
      assert !dt.well_formed?
      assert !dt.valid?

      # timezone is OK

      dt = Fl::Framework::Core::Icalendar::Datetime.new('TZID=America/Los_Angeles:20140101T102030')
      assert dt.well_formed?
      assert dt.valid?

      # no timezone

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T102030')
      assert dt.well_formed?
      assert dt.valid?

      # 'Z' timezone

      dt = Fl::Framework::Core::Icalendar::Datetime.new('20140101T102030Z')
      assert dt.well_formed?
      assert dt.valid?

      # unknown timezone

      dt = Fl::Framework::Core::Icalendar::Datetime.new('TZID=America/Menlo_Park:20140101T102030')
      assert dt.well_formed?
      assert !dt.valid?
    end

    test "property factory" do
      s = 'DTEND;VALUE=DATE:19980704'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Dtend, p
      assert_equal '19980704', p.value
      assert_equal 'DATE', p.type
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('19980704')
      assert_equal dt2.to_i, dt1.to_i

      s = 'DTEND:19980704'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Dtend, p
      assert_equal '19980704', p.value
      assert_equal 'DATE', p.type
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('19980704')
      assert_equal dt2.to_i, dt1.to_i

      s = 'DUE:19980704'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Due, p
      assert_equal '19980704', p.value
      assert_equal 'DATE', p.type
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('19980704')
      assert_equal dt2.to_i, dt1.to_i

      s = 'DUE:19980704T100000'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Due, p
      assert_equal '19980704T100000', p.value
      assert_equal 'DATE-TIME', p.type
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('19980704T100000')
      assert_equal dt2.to_i, dt1.to_i

      s = 'DTSTART;VALUE=DATE-TIME;TZID=America/Los_Angeles:19980704T1020'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Dtstart, p
      assert_equal 'TZID=America/Los_Angeles:19980704T1020', p.value
      assert_equal 'DATE-TIME', p.type
      assert_equal 'America/Los_Angeles', p.tzid
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:19980704T1020')
      assert_equal dt2.to_i, dt1.to_i

      s = 'DTSTART;TZID=America/Los_Angeles;VALUE=DATE-TIME:19980704T1020'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Dtstart, p
      assert_equal 'TZID=America/Los_Angeles:19980704T1020', p.value
      assert_equal 'DATE-TIME', p.type
      assert_equal 'America/Los_Angeles', p.tzid
      dt1 = p.datetime
      dt2 = Fl::Framework::Core::Icalendar.parse('TZID=America/Los_Angeles:19980704T1020')
      assert_equal dt2.to_i, dt1.to_i

      s = 'GEO:37.386013;-122.082932'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Base, p
      assert_equal '37.386013;-122.082932', p.value

      s = 'ATTACH;FMTTYPE=application/postscript:ftp://example.com/pub/reports/r-960812.ps'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Base, p
      x = {
        :name => 'ATTACH',
        :params => {
          :FMTTYPE => 'application/postscript'
        },
        :value => 'ftp://example.com/pub/reports/r-960812.ps'
      }
      assert_equal x, p.to_hash
      assert_equal 'ftp://example.com/pub/reports/r-960812.ps', p.value

      s = 'LOCATION:Conference Room - F123\, Bldg. 002'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Location, p
      x = {
        :name => 'LOCATION',
        :params => {
        },
        :value => 'Conference Room - F123, Bldg. 002'
      }
      assert_equal x, p.to_hash
      assert_equal 'Conference Room - F123, Bldg. 002', p.value

      s = 'LOCATION;ALTREP="http://xyzcorp.com/conf-rooms/f123.vcf":Conference Room - F123\, Bldg. 002'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Location, p
      x = {
        :name => 'LOCATION',
        :params => {
          :ALTREP => 'http://xyzcorp.com/conf-rooms/f123.vcf'
        },
        :value => 'Conference Room - F123, Bldg. 002'
      }
      assert_equal x, p.to_hash
      assert_equal 'Conference Room - F123, Bldg. 002', p.value

      s = 'SUMMARY:Here is a summary'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Summary, p
      assert_equal 'Here is a summary', p.value

      s = 'URL:http://example.com/pub/calendars/jsmith/mytime.ics'
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Url, p
      assert_equal 'http://example.com/pub/calendars/jsmith/mytime.ics', p.value

      d = 'Meeting to provide technical review for "Phoenix" design.\nHappy Face Conference Room. Phoenix design team MUST attend this meeting.\nRSVP to team leader.'
      s = "DESCRIPTION:#{d}"
      p = Fl::Framework::Core::Icalendar::Property::Base.make_property(s)
      assert !p.nil?
      assert_instance_of Fl::Framework::Core::Icalendar::Property::Description, p
      assert_equal d.gsub('\n', "\n"), p.value
    end

    test "timezone offset" do
      assert_equal -480, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('-08:00')
      assert_equal 480, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('+08:00')

      assert_equal -300, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('-05:00')
      assert_equal 300, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('+05:00')

      assert_equal -90, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('-01:30')
      assert_equal 90, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('+01:30')

      assert_equal 0, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('-00:00')
      assert_equal 0, Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('+00:00')

      assert_nil Fl::Framework::Core::Icalendar::Datetime.parse_tzoffset('00:00')

      assert_equal '-08:00', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(-480)
      assert_equal '+08:00', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(480)

      assert_equal '-05:00', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(-300)
      assert_equal '+05:00', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(300)

      assert_equal '-01:30', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(-90)
      assert_equal '+01:30', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(90)

      assert_equal '+00:00', Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(0)

      assert_nil Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(-1000)
      assert_nil Fl::Framework::Core::Icalendar::Datetime.format_tzoffset(1000)
    end

    test 'rfc formats' do
      s_3339 = '2016-02-10T10:20:40-05:00'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_3339)
      dth = { :DATE => '20160210', :TIME => '102040', :TZOFFSET => -300 }
      assert_equal dth, dt.to_hash
      assert_equal -300, dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal '20160210T102040', dt.to_rfc5545
      s_5545 = 'TZID=America/New_York:20160210T102040'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_5545)
      dth = { :DATE => '20160210', :TIME => '102040', :TZID => 'America/New_York' }
      assert_equal dth, dt.to_hash
      assert_equal -300, dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal s_5545, dt.to_rfc5545

      s_3339 = '2016-08-10T10:20:40-05:00'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_3339)
      dth = { :DATE => '20160810', :TIME => '102040', :TZOFFSET => -300 }
      assert_equal dth, dt.to_hash
      assert_equal -300, dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal '20160810T102040', dt.to_rfc5545
      s_5545 = 'TZID=America/New_York:20160810T102040'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_5545)
      dth = { :DATE => '20160810', :TIME => '102040', :TZID => 'America/New_York' }
      assert_equal dth, dt.to_hash
      assert_equal -300, dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal s_5545, dt.to_rfc5545

      s = '2016-02-10T10:20:40-05:00'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s)
      ts_0500 = dt.to_i
      assert_equal Time.parse(s).to_i, ts_0500
      dt.timezone_offset = '-08:00'
      assert_equal -480, dt.timezone_offset
      ts_0800 = dt.to_i
      assert_equal (-180 * 60), ts_0500 - ts_0800
      dt.timezone = 'America/Los_Angeles'
      ts_ca = dt.to_i
      assert_equal (-180 * 60), ts_0500 - ts_ca

      s_3339 = '2016-02-10'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_3339)
      dth = { :DATE => '20160210' }
      assert_equal dth, dt.to_hash
      assert_nil dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal '20160210', dt.to_rfc5545
      s_5545 = '20160210'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_5545)
      dth = { :DATE => '20160210' }
      assert_equal dth, dt.to_hash
      assert_nil dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal s_5545, dt.to_rfc5545
      s_5545 = 'TZID=America/New_York:20160210'
      dt = Fl::Framework::Core::Icalendar::Datetime.new(s_5545)
      dth = { :DATE => '20160210', :TZID => 'America/New_York' }
      assert_equal dth, dt.to_hash
      assert_equal -300, dt.timezone_offset
      assert_equal s_3339, dt.to_rfc3339
      assert_equal s_5545, dt.to_rfc5545
    end
  end
end
